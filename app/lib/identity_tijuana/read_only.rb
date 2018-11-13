module IdentityTijuana
  module ReadOnly
    def self.included(mod)
      mod.establish_connection Settings.tijuana.read_only_database_url if Settings.tijuana.read_only_database_url
    end
  end
end