class MemberExternalId < ApplicationRecord
  include ReadWriteIdentity
  belongs_to :member

  validates_presence_of :member
  validates_uniqueness_of :external_id, scope: :system
end
