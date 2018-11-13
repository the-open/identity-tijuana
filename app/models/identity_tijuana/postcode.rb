module IdentityTijuana
  class Postcode < ApplicationRecord
    include ReadWrite
    self.table_name = 'postcodes'
    has_many :users
  end
end
