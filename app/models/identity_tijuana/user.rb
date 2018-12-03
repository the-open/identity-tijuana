module IdentityTijuana
  class User < ApplicationRecord
    include ReadWrite
    self.table_name = 'users'
    has_many :taggings
    has_many :tags, through: :users
    belongs_to :postcode, optional: true

    def import
      member_hash = {
        ignore_phone_number_match: true,
        firstname: first_name,
        lastname: last_name,
        emails: [{ email: email }],
        phones: [],
        addresses: [{ line1: street_address, town: suburb, country: country_iso, state: postcode.try(:state), postcode: postcode.try(:number) }],
        external_ids: { tijuana: id },
        subscriptions: [{ id: Subscription::EMAIL_SUBSCRIPTION, action: is_member ? 'subscribe' : 'unsubscribe' }]
      }
      if Settings.tijuana.opt_out_subscription_id
        member_hash[:subscriptions].push({
          id: Settings.tijuana.opt_out_subscription_id,
          action: do_not_call ? 'unsubscribe' : 'subscribe'
        })
      end

      member_hash[:phones].push(phone: home_number) if home_number.present?
      member_hash[:phones].push(phone: mobile_number) if mobile_number.present?

      Member.delay.upsert_member(member_hash, 'tijuana:fetch_updated_users')
    end
  end
end
class User < IdentityTijuana::User
end
