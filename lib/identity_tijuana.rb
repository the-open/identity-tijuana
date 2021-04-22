require "identity_tijuana/engine"

module IdentityTijuana
  SYSTEM_NAME = 'tijuana'
  SYNCING = 'tag'
  CONTACT_TYPE = 'email'
  PULL_JOBS = [[:fetch_updated_users, 10.minutes], [:fetch_latest_taggings, 5.minutes]]
  MEMBER_RECORD_DATA_TYPE='object'

  def self.push(sync_id, member_ids, external_system_params)
    begin
      members = Member.where(id: member_ids).with_email
      yield members, nil
    rescue => e
      raise e
    end
  end

  def self.push_in_batches(sync_id, members, external_system_params)
    begin
      members.in_batches(of: Settings.tijuana.push_batch_amount).each_with_index do |batch_members, batch_index|
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

  def self.description(sync_type, external_system_params, contact_campaign_name)
    external_system_params_hash = JSON.parse(external_system_params)
    if sync_type === 'push'
      "#{SYSTEM_NAME.titleize} - #{SYNCING.titleize}: ##{external_system_params_hash['tag']} (#{CONTACT_TYPE})"
    else
      "#{SYSTEM_NAME.titleize}: #{external_system_params_hash['pull_job']}"
    end
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

  def self.get_pull_jobs
    defined?(PULL_JOBS) && PULL_JOBS.is_a?(Array) ? PULL_JOBS : []
  end

  def self.get_push_jobs
    defined?(PUSH_JOBS) && PUSH_JOBS.is_a?(Array) ? PUSH_JOBS : []
  end

  def self.pull(sync_id, external_system_params)
    begin
      pull_job = JSON.parse(external_system_params)['pull_job'].to_s
      self.send(pull_job, sync_id) do |records_for_import_count, records_for_import, records_for_import_scope, pull_deferred|
        yield records_for_import_count, records_for_import, records_for_import_scope, pull_deferred
      end
    rescue => e
      raise e
    end
  end

  def self.fetch_updated_users(sync_id)
    ## Do not run method if another worker is currently processing this method
    yield 0, {}, {}, true if self.worker_currenly_running?(__method__.to_s)

    started_at = DateTime.now
    last_updated_at = Time.parse(Sidekiq.redis { |r| r.get 'tijuana:users:last_updated_at' } || '1970-01-01 00:00:00')
    updated_users = User.updated_users(last_updated_at)
    updated_users_all = User.updated_users_all(last_updated_at)
    updated_users.each do |user|
      User.import(user.id, sync_id)
    end

    unless updated_users.empty?
      Sidekiq.redis { |r| r.set 'tijuana:users:last_updated_at', updated_users.last.updated_at }
    end

    execution_time_seconds = ((DateTime.now - started_at) * 24 * 60 * 60).to_i
    yield(
      updated_users.size,
      updated_users.pluck(:id),
      {
        scope: 'tijuana:users:last_updated_at',
        scope_limit: Settings.tijuana.pull_batch_amount,
        from: last_updated_at,
        to: updated_users.empty? ? nil : updated_users.last.updated_at,
        started_at: started_at,
        completed_at: DateTime.now,
        execution_time_seconds: execution_time_seconds,
        remaining_behind: updated_users_all.count
      },
      false
    )
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

  def self.fetch_latest_taggings(sync_id)
    ## Do not run method if another worker is currently processing this method
    yield 0, {}, {}, true if self.worker_currenly_running?(__method__.to_s)

    latest_tagging_scope_limit = 50000
    started_at = DateTime.now
    last_id = (Sidekiq.redis { |r| r.get 'tijuana:taggings:last_id' } || 0).to_i
    users_last_updated_at = Time.parse(Sidekiq.redis { |r| r.get 'tijuana:users:last_updated_at' } || '1970-01-01 00:00:00')
    connection = ActiveRecord::Base.connection == List.connection ? ActiveRecord::Base.connection : List.connection

    tags_remaining_behind_sql = %{
      SELECT distinct(t.name)
      FROM taggings tu #{'FORCE INDEX (PRIMARY)' unless Settings.tijuana.database_url.start_with? 'postgres'}
      JOIN tags t
        ON t.id = tu.tag_id
      WHERE tu.id > #{last_id}
        AND taggable_type = 'User'
        AND (tu.created_at < #{connection.quote(users_last_updated_at)} OR tu.created_at is null)
        AND t.name like '%_syncid%'
    }

    scoped_latest_taggings_sql = %{
      SELECT tu.taggable_id, t.name, tu.id, t.author_id, tu.created_at
      FROM taggings tu #{'FORCE INDEX (PRIMARY)' unless Settings.tijuana.database_url.start_with? 'postgres'}
      JOIN tags t
        ON t.id = tu.tag_id
      WHERE tu.id > #{last_id}
        AND taggable_type = 'User'
        AND (tu.created_at < #{connection.quote(users_last_updated_at)} OR tu.created_at is null)
        AND t.name like '%_syncid%'
      ORDER BY tu.id
      LIMIT #{latest_tagging_scope_limit}
    }

    puts 'Getting latest taggings'
    tags_remaining_results = IdentityTijuana::Tagging.connection.execute(tags_remaining_behind_sql).to_a
    results = IdentityTijuana::Tagging.connection.execute(scoped_latest_taggings_sql).to_a

    unless results.empty?
      puts 'Creating value strings'
      results = results.map { |row| row.try(:values) || row } # deal with results returned in array or hash form
      value_strings = results.map do |row|
        "(#{connection.quote(row[0])}, #{connection.quote(row[1])}, #{connection.quote(row[2])})"
      end

      puts 'Inserting value strings and merging'
      table_name = "tmp_#{SecureRandom.hex(16)}"
      connection.execute(%{
        CREATE TABLE #{table_name} (tijuana_id TEXT, tag TEXT, tijuana_author_id INTEGER);
        INSERT INTO #{table_name} VALUES #{value_strings.join(',')};
        CREATE INDEX #{table_name}_tijuana_id ON #{table_name} (tijuana_id);
        CREATE INDEX #{table_name}_tag ON #{table_name} (tag);
      })

      connection.execute(%{
        INSERT INTO lists (name, author_id, created_at, updated_at)
        SELECT DISTINCT 'TIJUANA TAG: ' || et.tag, author_id, current_timestamp, current_timestamp
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
        list = List.find(list_id)
        user_results = User.connection.execute("SELECT email, first_name, last_name FROM users WHERE id = #{ActiveRecord::Base.connection.quote(list.author_id)}").to_a
        if user_results && user_results[0]
          ## Create Members for both the user and campaign contact
          author = UpsertMember.call(
            {
              emails: [{ email: user_results[0][0] }],
              firstname: user_results[0][1],
              lastname: user_results[0][2],
              external_ids: { tijuana: list.author_id },
            },
            entry_point: "#{SYSTEM_NAME}:#{__method__.to_s}",
            ignore_name_change: false
          )
          List.find(list_id).update!(author_id: author.id)
        end
        CountListMembersWorker.perform_async(list_id)
      end

      if Settings.options.use_redshift
        List.find(list_ids).each(&:copy_to_redshift)
      end

      Sidekiq.redis { |r| r.set 'tijuana:taggings:last_id', results.last[2] }
    end

    execution_time_seconds = ((DateTime.now - started_at) * 24 * 60 * 60).to_i
    yield(
      results.size,
      results,
      {
        scope: 'tijuana:taggings:last_id',
        scope_limit: latest_tagging_scope_limit,
        from: results.empty? ? nil : results.first[4],
        to: results.empty? ? nil : results.last[4],
        started_at: started_at,
        completed_at: DateTime.now,
        execution_time_seconds: execution_time_seconds,
        remaining_behind: tags_remaining_results.count
      },
      false
    )
  end
end
