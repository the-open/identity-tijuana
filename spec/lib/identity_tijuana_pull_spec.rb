require 'rails_helper'
require 'identity_tijuana'

RSpec.configure do |config|
  config.before(:all) do
    FactoryBot.definition_file_paths << File.expand_path('../../factories', __FILE__)
    FactoryBot.reload
  end
end

RSpec.describe ExternalSystems::IdentityTijuana do
  before(:each) do
    DatabaseCleaner[:active_record].clean_with(:truncation, :except => %w[permissions subscriptions])
    DatabaseCleaner[:active_record, db: ExternalSystems::IdentityTijuana::User].strategy = :truncation
    DatabaseCleaner[:active_record, db: ExternalSystems::IdentityTijuana::User].start
    DatabaseCleaner[:active_record, db: ExternalSystems::IdentityTijuana::User].clean
  end

  context '#pull_updated_users' do
    before do
      allow(Settings).to receive_message_chain("options.default_phone_country_code") { '61' }
      allow(Settings).to receive_message_chain("options.allow_subscribe_via_upsert_member") { true }
      allow(Settings).to receive_message_chain("options.allow_upsert_create_subscriptions") { true }
      allow(Settings).to receive_message_chain("options.default_member_opt_in_subscriptions") { true }
      allow(Settings).to receive_message_chain("options.default_mobile_phone_national_destination_code") { 4 }
      allow(Settings).to receive_message_chain("tijuana.pull_batch_amount") { nil }
      allow(Settings).to receive_message_chain("tijuana.push_batch_amount") { nil }
    end

    it 'adds members' do
      user = FactoryBot.create(:tijuana_user)
      ExternalSystems::IdentityTijuana.pull_updated_users() {}
      expect(Member.find_by(email: user.email)).to have_attributes(name: "#{user.first_name} #{user.last_name}")
      expect(Member.count).to eq(1)
    end

    it 'upserts members based on email' do
      user = FactoryBot.create(:tijuana_user)
      member_with_email = FactoryBot.create(:member)
      member_with_email.update_attributes(email: user.email)
      expect(Member.count).to eq(1)
      expect(Member.first).not_to have_attributes(first_name: user.first_name)

      ExternalSystems::IdentityTijuana.pull_updated_users() {}
      expect(Member.find_by(email: user.email)).to have_attributes(name: "#{user.first_name} #{user.last_name}")
      expect(Member.count).to eq(1)
    end

    it 'subscribes people to email and calling and sms' do
      user = FactoryBot.create(:tijuana_user, is_member: true, do_not_call: false, do_not_sms: false)
      member_with_email_and_calling = FactoryBot.create(:member)
      member_with_email_and_calling.update_attributes(email: user.email)


      ExternalSystems::IdentityTijuana.pull_updated_users() {}
      member_with_email_and_calling.reload
      expect(member_with_email_and_calling.is_subscribed_to?(Subscription::EMAIL_SUBSCRIPTION.id)).to eq(true)
      expect(member_with_email_and_calling.is_subscribed_to?(Subscription::CALLING_SUBSCRIPTION.id)).to eq(true)
      expect(member_with_email_and_calling.is_subscribed_to?(Subscription::SMS_SUBSCRIPTION.id)).to eq(true)
    end

    it 'unsubscribes people' do
      user = FactoryBot.create(:tijuana_user, is_member: false, do_not_call: true, do_not_sms: true)
      member_with_email_and_calling = FactoryBot.create(:member)
      member_with_email_and_calling.update_attributes(email: user.email)

      ExternalSystems::IdentityTijuana.pull_updated_users() {}

      member_with_email_and_calling.reload
      expect(member_with_email_and_calling.is_subscribed_to?(Subscription::EMAIL_SUBSCRIPTION.id)).to eq(false)
      expect(member_with_email_and_calling.is_subscribed_to?(Subscription::CALLING_SUBSCRIPTION.id)).to eq(false)
      expect(member_with_email_and_calling.is_subscribed_to?(Subscription::SMS_SUBSCRIPTION.id)).to eq(false)
    end

    it 'upserts members based on phone' do
      member = FactoryBot.create(:member)
      member.update_phone_number('61427700300')

      user = FactoryBot.create(:tijuana_user, mobile_number: '0427700300', email: 'x@example.com')

      ExternalSystems::IdentityTijuana.pull_updated_users() {}

      expect(Member.find_by_phone('61427700300')).to have_attributes(name: "#{user.first_name} #{user.last_name}")
      expect(Member.count).to eq(2)
    end

    it 'correctly adds phone numbers' do
      FactoryBot.create(:tijuana_user, first_name: 'Phone', last_name: 'McPhone', email: 'phone@example.com', mobile_number: '0427700300', home_number: '(02) 8188 2888')

      ExternalSystems::IdentityTijuana.pull_updated_users() {}
      expect(Member.count).to eq(1)
      expect(Member.first.phone_numbers.count).to eq(2)
      expect(Member.first.phone_numbers.find_by(phone: '61427700300')).not_to be_nil
      expect(Member.first.phone_numbers.find_by(phone: '61281882888')).not_to be_nil
    end

    it 'correctly adds addresses' do
      FactoryBot.create(:tijuana_user, first_name: 'Address', last_name: 'McAdd', email: 'address@example.com', street_address: '18 Mitchell Street', suburb: 'Bondi', postcode: ExternalSystems::IdentityTijuana::Postcode.new(number: 2026, state: 'NSW'))

      ExternalSystems::IdentityTijuana.pull_updated_users() {}
      expect(Member.first).to have_attributes(first_name: 'Address', last_name: 'McAdd', email: 'address@example.com')
      expect(Member.first.address).to have_attributes(line1: '18 Mitchell Street', town: 'Bondi', postcode: '2026', state: 'NSW')
    end
  end
end
