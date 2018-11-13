class AreaMembership < ApplicationRecord
  include ReadWriteIdentity

  belongs_to :member
  belongs_to :area
end
