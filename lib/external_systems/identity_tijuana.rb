module ExternalSystems::IdentityTijuana
  SYSTEM_NAME = 'tijuana'
  PULL_BATCH_AMOUNT = 1000
  PUSH_BATCH_AMOUNT = 1000
  SYNCING = 'tag'
  CONTACT_TYPE = 'email'
  PULL_JOBS = [:fetch_updated_users, :fetch_latest_taggings]
  MEMBER_RECORD_DATA_TYPE='object'

  class << self
    def self.push(sync_id, member_ids, external_system_params)
    end

    def self.push_in_batches(sync_id, members, external_system_params)
    end

    def self.description(external_system_params, contact_campaign_name)
      external_system_params_hash = JSON.parse(external_system_params)
      "#{SYSTEM_NAME.titleize}: #{external_system_params_hash['pull_job']}"
    end

    def self.get_pull_batch_amount
      PULL_BATCH_AMOUNT
    end

    def self.get_push_batch_amount
      PUSH_BATCH_AMOUNT
    end

    def self.get_pull_jobs
      defined?(PULL_JOBS) && PULL_JOBS.is_a?(Array) ? PULL_JOBS : []
    end

    def self.get_push_jobs
      defined?(PUSH_JOBS) && PUSH_JOBS.is_a?(Array) ? PUSH_JOBS : []
    end

    def self.pull(sync_id, external_system_params)
    end

    def self.fetch_updated_users
      Rails.logger.warn "Update users"
    end

    def self.fetch_users_for_dedupe
    end

    def self.fetch_latest_taggings
      Rails.logger.warn "Update taggings"
    end
  end
end
