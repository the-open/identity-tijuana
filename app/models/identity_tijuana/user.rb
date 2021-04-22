module IdentityTijuana
  class User < ApplicationRecord
    include ReadWrite
    self.table_name = 'users'
    has_many :taggings
    has_many :tags, through: :users
    belongs_to :postcode, optional: true

    scope :updated_users, -> (last_updated_at) {
      includes(:postcode)
      .where('users.updated_at >= ?', last_updated_at)
      .order('users.updated_at')
      .limit(Settings.tijuana.pull_batch_amount)
    }

    scope :updated_users_all, -> (last_updated_at) {
      includes(:postcode)
      .where('users.updated_at >= ?', last_updated_at)
    }

    def self.import(user_id, sync_id)
      user = User.find(user_id)
      user.import(sync_id)
    end

    def import(sync_id)
      member_hash = {
        ignore_phone_number_match: true,
        firstname: first_name,
        lastname: last_name,
        emails: [{ email: email }],
        phones: [],
        addresses: [{ line1: street_address, town: suburb, country: country_iso, state: postcode.try(:state), postcode: postcode.try(:number) }],
        external_ids: { tijuana: id },
        subscriptions: []
      }

      if Settings.tijuana.email_subscription_id
        member_hash[:subscriptions].push({
          id: Settings.tijuana.email_subscription_id,
          action: !is_member ? 'unsubscribe' : 'subscribe'
        })
      end

      if Settings.tijuana.calling_subscription_id
        member_hash[:subscriptions].push({
          id: Settings.tijuana.calling_subscription_id,
          action: do_not_call ? 'unsubscribe' : 'subscribe'
        })
      end

      if Settings.tijuana.sms_subscription_id
        member_hash[:subscriptions].push({
          id: Settings.tijuana.sms_subscription_id,
          action: do_not_sms ? 'unsubscribe' : 'subscribe'
        })
      end

      standard_home = PhoneNumber.standardise_phone_number(home_number) if home_number.present?
      standard_mobile = PhoneNumber.standardise_phone_number(mobile_number) if mobile_number.present?
      member_hash[:phones].push(phone: standard_home) if home_number.present?
      member_hash[:phones].push(phone: standard_mobile) if mobile_number.present? and standard_mobile != standard_home

      UpsertMember.call(
        member_hash,
        entry_point: 'tijuana:fetch_updated_users',
        ignore_name_change: false
      )
    end
  end
end
class User < IdentityTijuana::User
end
