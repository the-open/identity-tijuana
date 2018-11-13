module IdentityTijuana
  class Tag < ApplicationRecord
    include ReadWrite
    self.table_name = 'tags'
    has_many :taggings
    has_many :users, through: :taggings
  end
end
