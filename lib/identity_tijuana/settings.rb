module ExternalSystems::IdentityTijuana
  class Settings
    class Tijuana
      def self.pull_batch_amount
        ENV['PULL_BATCH_AMOUNT']
      end

      def self.push_batch_amount
        ENV['PUSHL_BATCH_AMOUNT']
      end

      def self.database_url
        ENV['TIJUANA_DATABASE_URL']
      end
    end

    class << self
      def tijuana
        Tijuana
      end
    end
  end
end
