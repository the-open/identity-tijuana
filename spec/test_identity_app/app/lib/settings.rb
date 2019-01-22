# This patch allows accessing the settings hash with dot notation
class Hash
  def method_missing(method, *opts)
    m = method.to_s
    return self[m] if key?(m)
    super
  end
end

class Settings
  def self.tijuana
    return {
      "database_url" => ENV['TIJUANA_DATABASE_URL'],
      "read_only_database_url" => ENV['TIJUANA_DATABASE_URL'],
      "api" => {
        "url" => ENV['TIJUANA_API_URL'],
        "secret" => ENV['TIJUANA_API_SECRET']
      },
      "sync_batch_size" => 1000,
      "opt_out_email_subscription_id" => 4,
      "opt_out_calling_subscription_id" => 4
    }
  end

  def self.kooragang
    return {
      "opt_out_subscription_id" => 3
    }
  end

  def self.options
    return {
      "use_redshift" => true,
      "default_phone_country_code" => '61'
    }
  end

  def self.databases
    return {
      "zip_schema" => false,
      "zip_primary_key" => false
    }
  end

  def self.geography
    return {
      "postcode_dash" => false
    }
  end
end
