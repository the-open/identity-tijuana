require "identity_tijuana/engine"

module IdentityTijuana
  SYSTEM_NAME = 'tijuana'
  PULL_BATCH_AMOUNT = 1000
  PUSH_BATCH_AMOUNT = 1000
  SYNCING = 'tag'
  CONTACT_TYPE = 'email'
  PULL_JOBS = [[:fetch_updated_users, 10.minutes], [:fetch_latest_taggings, 5.minutes]]

  def self.push(sync_id, members, external_system_params)
    begin
      yield members.with_email, nil
    rescue => e
      raise e
    end
  end

  def self.push_in_batches(sync_id, members, external_system_params)
    begin
      members.in_batches(of: get_push_batch_amount).each_with_index do |batch_members, batch_index|
        tag = JSON.parse(external_system_params)['tag']
        rows = ActiveModel::Serializer::CollectionSerializer.new(
          batch_members,
          serializer: TijuanaMemberSyncPushSerializer
        ).as_json.to_a.map{|member| member[:email]}
        tijuana = API.new
        tijuana.tag_emails(tag, rows)

        #TODO return write results here
        yield batch_index, 0
      end
    rescue => e
      raise e
    end
  end

  def self.description(external_system_params, contact_campaign_name)
    "#{SYSTEM_NAME.titleize} - #{SYNCING.titleize}: ##{JSON.parse(external_system_params)['tag']} (#{CONTACT_TYPE})"
  end

  def self.worker_currenly_running?(method_name)
    workers = Sidekiq::Workers.new
    workers.each do |_process_id, _thread_id, work|
      matched_process = work["payload"]["args"] = [SYSTEM_NAME, method_name]
      if matched_process
        puts ">>> #{SYSTEM_NAME.titleize} #{method_name} skipping as worker already running ..."
        return true
      end
    end
    puts ">>> #{SYSTEM_NAME.titleize} #{method_name} running ..."
    return false
  end

  def self.get_pull_batch_amount
    Settings.tijuana.pull_batch_amount || PULL_BATCH_AMOUNT
  end

  def self.get_push_batch_amount
    Settings.tijuana.push_batch_amount || PUSH_BATCH_AMOUNT
  end

  def self.get_pull_jobs
    defined?(PULL_JOBS) && PULL_JOBS.is_a?(Array) ? PULL_JOBS : []
  end

  def self.fetch_updated_users
    ## Do not run method if another worker is currently processing this method
    return if self.worker_currenly_running?(__method__.to_s)

    last_updated_at = Time.parse(Sidekiq.redis { |r| r.get 'tijuana:users:last_updated_at' } || '1970-01-01 00:00:00')
    updated_users = User.updated_users(last_updated_at)
    updated_users.each do |user|
      User.delay(retry: false, queue: 'low').import(user.id)
    end

    unless updated_users.empty?
      Sidekiq.redis { |r| r.set 'tijuana:users:last_updated_at', updated_users.last.updated_at }
    end

    updated_users.size
  end

  def self.fetch_users_for_dedupe
    i = 0
    loop do
      results = User.connection.execute("SELECT email, first_name, last_name, mobile_number, street_address, suburb, country_iso, REPLACE(p.number,' ','') FROM users u JOIN postcodes p ON u.postcode_id = p.id LIMIT 10000 OFFSET #{i * 10_000}").to_a
      break if results.empty?

      # deduper doesn't like empty strings
      value_string = results.map { |x| '(' + x.map { |v| v.present? ? ActiveRecord::Base.connection.quote(v.downcase) : 'NULL' }.join(',') + ')' }.join(',')

      ActiveRecord::Base.connection.execute("INSERT INTO dedupe_processed_records (email, first_name, last_name, phone, line1, town, country, postcode) VALUES #{value_string}")
      i += 1
      puts "Done #{i * 10_000}"
    end
  end

  def self.fetch_latest_taggings
    ## Do not run method if another worker is currently processing this method
    return if self.worker_currenly_running?(__method__.to_s)

    last_id = (Sidekiq.redis { |r| r.get 'tijuana:taggings:last_id' } || 0).to_i
    users_last_updated_at = Time.parse(Sidekiq.redis { |r| r.get 'tijuana:users:last_updated_at' } || '1970-01-01 00:00:00')
    connection = ActiveRecord::Base.connection == List.connection ? ActiveRecord::Base.connection : List.connection


    sql = %{
      SELECT tu.taggable_id, t.name, tu.id
      FROM taggings tu #{'FORCE INDEX (PRIMARY)' unless Settings.tijuana.database_url.start_with? 'postgres'}
      JOIN tags t
        ON t.id = tu.tag_id
      WHERE tu.id > #{last_id}
        AND taggable_type = 'User'
        AND (tu.created_at < #{connection.quote(users_last_updated_at)} OR tu.created_at is null)
        AND t.name like '%_syncid%'
      ORDER BY tu.id
      LIMIT 50000
    }

    puts 'Getting latest taggings'
    results = IdentityTijuana::Tagging.connection.execute(sql).to_a

    unless results.empty?
      puts 'Creating value strings'
      results = results.map { |row| row.try(:values) || row } # deal with results returned in array or hash form
      value_strings = results.map do |row|
        "(#{connection.quote(row[0])}, #{connection.quote(row[1])})"
      end

      puts 'Inserting value strings and merging'
      table_name = "tmp_#{SecureRandom.hex(16)}"
      connection.execute(%{
        CREATE TABLE #{table_name} (tijuana_id TEXT, tag TEXT);
        INSERT INTO #{table_name} VALUES #{value_strings.join(',')};
        CREATE INDEX #{table_name}_tijuana_id ON #{table_name} (tijuana_id);
        CREATE INDEX #{table_name}_tag ON #{table_name} (tag);
      })

      connection.execute(%{
        INSERT INTO lists (name, created_at, updated_at)
        SELECT DISTINCT 'TIJUANA TAG: ' || et.tag, current_timestamp, current_timestamp
        FROM #{table_name} et
        LEFT JOIN lists l
          ON l.name = 'TIJUANA TAG: ' || et.tag
        WHERE l.id is null;
        })

      connection.execute(%Q{
        INSERT INTO list_members (member_id, list_id, created_at, updated_at)
        SELECT DISTINCT mei.member_id, l.id, current_timestamp, current_timestamp
        FROM #{table_name} et
        JOIN lists l
          ON l.name = 'TIJUANA TAG: ' || et.tag
        JOIN member_external_ids mei
          ON (mei.external_id = et.tijuana_id AND mei.system = 'tijuana')
        LEFT JOIN list_members lm
          ON lm.member_id = mei.member_id AND lm.list_id = l.id
        WHERE lm.id is null;
      })

      list_ids = connection.execute(%Q{SELECT DISTINCT l.id
        FROM #{table_name} et
        JOIN lists l
          ON l.name = 'TIJUANA TAG: ' || et.tag
      }).to_a.map { |row| row['id'] }

      connection.execute("DROP TABLE #{table_name};")

      list_ids.each do |list_id|
        CountListMembersWorker.perform_async(list_id)
      end

      if Settings.options.use_redshift
        List.find(list_ids).each(&:copy_to_redshift)
      end

      Sidekiq.redis { |r| r.set 'tijuana:taggings:last_id', results.last[2] }
    end

    results.size
  end
end
