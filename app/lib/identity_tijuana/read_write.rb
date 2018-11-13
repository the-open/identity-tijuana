module IdentityTijuana
  module ReadWrite
    def self.included(mod)
      mod.establish_connection Settings.tijuana.database_url if Settings.tijuana.database_url
    end
  end
end
