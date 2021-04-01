require 'identity_tijuana/application_record'
require 'identity_tijuana/readwrite'

module ExternalSystems::IdentityTijuana
  class User < ApplicationRecord
    include ReadWrite
    self.table_name = 'users'
    has_many :taggings
    has_many :tags, through: :users
    belongs_to :postcode, optional: true

    scope :updated_users, -> (last_updated_at) {
      includes(:postcode)
      .where('users.updated_at > ?', last_updated_at)
      .order('users.updated_at')
        .limit(Settings.tijuana.pull_batch_amount)
    }

    scope :updated_users_all, -> (last_updated_at) {
      includes(:postcode)
      .where('users.updated_at > ?', last_updated_at)
    }

    def self.import(user_id)
      user = User.find(user_id)
      user.import(user_id)
    end

    def import(user_id)
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

      member_hash[:subscriptions].push({
        id: Subscription::EMAIL_SUBSCRIPTION.id,
        action: !is_member ? 'unsubscribe' : 'subscribe'
      })

      member_hash[:subscriptions].push({
        id: Subscription::CALLING_SUBSCRIPTION.id,
        action: do_not_call ? 'unsubscribe' : 'subscribe'
      })

      member_hash[:subscriptions].push({
        id: Subscription::SMS_SUBSCRIPTION.id,
        action: do_not_sms ? 'unsubscribe' : 'subscribe'
      })
     
      standard_home = PhoneNumber.standardise_phone_number(home_number) if home_number.present?
      standard_mobile = PhoneNumber.standardise_phone_number(mobile_number) if mobile_number.present?
      member_hash[:phones].push(phone: standard_home) if home_number.present?
      member_hash[:phones].push(phone: standard_mobile) if mobile_number.present? and standard_mobile != standard_home

      UpsertMember.new(
        member_hash,
        entry_point: 'tijuana:pull_updated_users',
        ignore_name_change: false
      ).call()
    end

    def self.export(member_id)
      member = Member.find(member_id)

      if member.entry_point.present? and not member.entry_point.starts_with? 'tijuana'
        user = User.find_by_email(member.email)

        user_hash = {
          first_name: member.first_name,
          last_name: member.last_name,
          mobile_number: member.phone_numbers.mobile.first&.phone,
          home_number: member.phone_numbers.landline.first&.phone,
          email: member.email
        }

        if user
          user.update!(user_hash)
        else
          User.create!(user_hash)
        end
      end
    end
  end
end
