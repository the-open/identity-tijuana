class Address < ApplicationRecord
  include ReadWriteIdentity
  belongs_to :member
  belongs_to :canonical_address, optional: true
end
