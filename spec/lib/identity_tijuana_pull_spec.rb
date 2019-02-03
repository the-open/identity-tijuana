require 'rails_helper'

describe IdentityTijuana do

  before(:all) do
    Sidekiq::Testing.inline!
  end

  before do
    clean_external_database
  end

  after(:all) do
    Sidekiq::Testing.fake!
  end

  context '#fetch_updated_users' do
    before do
      @email_sub = FactoryBot.create(:email_subscription)
      @calling_sub = FactoryBot.create(:calling_subscription)
      allow(Settings).to receive_message_chain("options.default_phone_country_code") { '61' }
      allow(Settings).to receive_message_chain("kooragang.opt_out_subscription_id") { @calling_sub.id }
    end

    it 'adds members' do
      user = FactoryBot.create(:tijuana_user)
      IdentityTijuana.fetch_updated_users
      expect(Member.find_by(email: user.email)).to have_attributes(name: "#{user.first_name} #{user.last_name}")
      expect(Member.count).to eq(1)
    end

    it 'upserts members based on email' do
      user = FactoryBot.create(:tijuana_user)
      member_with_email = FactoryBot.create(:member)
      member_with_email.update_attributes(email: user.email)
      expect(Member.count).to eq(1)
      expect(Member.first).not_to have_attributes(first_name: user.first_name)

      IdentityTijuana.fetch_updated_users
      expect(Member.find_by(email: user.email)).to have_attributes(name: "#{user.first_name} #{user.last_name}")
      expect(Member.count).to eq(1)
    end

    it 'subscribes people to email and calling' do
      user = FactoryBot.create(:tijuana_user, is_member: true, do_not_call: false)
      member_with_email_and_calling = FactoryBot.create(:member)
      member_with_email_and_calling.update_attributes(email: user.email)


      IdentityTijuana.fetch_updated_users
      member_with_email_and_calling.reload
      expect(member_with_email_and_calling.is_subscribed_to?(@email_sub)).to eq(true)
      expect(member_with_email_and_calling.is_subscribed_to?(@calling_sub)).to eq(true)
    end

    it 'unsubscribes people' do
      user = FactoryBot.create(:tijuana_user, is_member: false, do_not_call: true)
      member_with_email_and_calling = FactoryBot.create(:member)
      member_with_email_and_calling.update_attributes(email: user.email)

      IdentityTijuana.fetch_updated_users

      member_with_email_and_calling.reload
      expect(member_with_email_and_calling.is_subscribed_to?(@email_sub)).to eq(false)
      expect(member_with_email_and_calling.is_subscribed_to?(@calling_sub)).to eq(false)
    end

    it 'upserts members based on phone' do
      Settings.stub_chain(:options, :default_mobile_phone_national_destination_code) { 4 }
      member = FactoryBot.create(:member)
      member.update_phone_number('61427700300')

      user = FactoryBot.create(:tijuana_user, mobile_number: '0427700300', email: '')

      IdentityTijuana.fetch_updated_users

      expect(Member.find_by_phone('61427700300')).to have_attributes(name: "#{user.first_name} #{user.last_name}")
      expect(Member.count).to eq(1)
    end

    it 'correctly adds phone numbers' do
      Settings.stub_chain(:options, :default_mobile_phone_national_destination_code) { 4 }
      FactoryBot.create(:tijuana_user, first_name: 'Phone', last_name: 'McPhone', email: 'phone@example.com', mobile_number: '0427700300', home_number: '(02) 8188 2888')

      IdentityTijuana.fetch_updated_users
      expect(Member.count).to eq(1)
      expect(Member.first.phone_numbers.count).to eq(2)
      expect(Member.first.phone_numbers.find_by(phone: '61427700300')).not_to be_nil
      expect(Member.first.phone_numbers.find_by(phone: '61281882888')).not_to be_nil
    end

    it 'correctly adds addresses' do
      FactoryBot.create(:tijuana_user, first_name: 'Address', last_name: 'McAdd', email: 'address@example.com', street_address: '18 Mitchell Street', suburb: 'Bondi', postcode: IdentityTijuana::Postcode.new(number: 2026, state: 'NSW'))

      IdentityTijuana.fetch_updated_users
      expect(Member.first).to have_attributes(first_name: 'Address', last_name: 'McAdd', email: 'address@example.com')
      expect(Member.first.address).to have_attributes(line1: '18 Mitchell Street', town: 'Bondi', postcode: '2026', state: 'NSW')
    end
  end

  context '#fetch_latest_taggings' do
    before do
      reef_user = FactoryBot.create(:tijuana_user)
      econoreef_user = FactoryBot.create(:tijuana_user)
      economy_user = FactoryBot.create(:tijuana_user)
      non_user = FactoryBot.create(:tijuana_user)

      reef_tag = FactoryBot.create(:tijuana_tag, name: 'reef_syncid')
      economy_tag = FactoryBot.create(:tijuana_tag, name: 'economy_syncid')
      non_sync_tag = FactoryBot.create(:tijuana_tag, name: 'bees')

      FactoryBot.create(:tijuana_tagging, taggable_id: reef_user.id, taggable_type: 'User', tag: reef_tag)
      FactoryBot.create(:tijuana_tagging, taggable_id: econoreef_user.id, taggable_type: 'User', tag: reef_tag)
      FactoryBot.create(:tijuana_tagging, taggable_id: econoreef_user.id, taggable_type: 'User', tag: economy_tag)
      FactoryBot.create(:tijuana_tagging, taggable_id: economy_user.id, taggable_type: 'User', tag: economy_tag)
      FactoryBot.create(:tijuana_tagging, taggable_id: non_user.id, taggable_type: 'User', tag: non_sync_tag)

      #4.times { FactoryBot.create(:list) }
    end

    it 'imports no taggings if last user updated at is before taggings updated_at' do
      IdentityTijuana.fetch_updated_users
      Sidekiq.redis { |r| r.set 'tijuana:users:last_updated_at', Date.today - 2 }
      IdentityTijuana.fetch_latest_taggings

      expect(List.count).to eq(0)
    end

    it 'imports taggings if created_at not set' do

      IdentityTijuana::Tagging.all.update_all(created_at: nil)
      IdentityTijuana.fetch_updated_users
      Sidekiq.redis { |r| r.set 'tijuana:users:last_updated_at', Date.today - 2 }

      IdentityTijuana.fetch_latest_taggings

      expect(List.count).to eq(2)
      expect(Member.count).to eq(4)
    end

    it 'imports tags' do

      IdentityTijuana.fetch_updated_users
      Sidekiq.redis { |r| r.set 'tijuana:users:last_updated_at', Date.today + 2 }

      IdentityTijuana.fetch_latest_taggings

      reef_tag = List.find_by(name: 'TIJUANA TAG: reef_syncid')
      economy_tag = List.find_by(name: 'TIJUANA TAG: economy_syncid')
      non_sync_tag = List.find_by(name: 'TIJUANA TAG: bees')

      expect(reef_tag).not_to be_nil
      expect(economy_tag).not_to be_nil
      expect(non_sync_tag).to be_nil

      # Member count has been calculated and is correct
      expect(reef_tag.member_count).to eq(2)
      expect(economy_tag.member_count).to eq(2)

      expect(Member.count).to eq(4)
    end
  end

  context '#get_pull_batch_amount' do
    context 'with no settings parameters set' do
      it 'should return default class constant' do
        expect(IdentityTijuana.get_pull_batch_amount).to eq(1000)
      end
    end
    context 'with settings parameters set' do
      before(:each) do
        Settings.stub_chain(:tijuana, :pull_batch_amount) { 100 }
      end
      it 'should return set variable' do
        expect(IdentityTijuana.get_pull_batch_amount).to eq(100)
      end
    end
  end
end
