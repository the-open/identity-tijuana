class Address < ApplicationRecord
  include ReadWriteIdentity
  attr_accessor :audit_data
  belongs_to :member
  belongs_to :canonical_address, optional: true
end
