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

  context '#push_updated_members' do

    it 'adds users' do
    end

    it 'upserts users based on email' do
    end

    it 'subscribes users to email, calling and sms' do
    end

    it 'unsubscribes users' do
    end

    it 'upserts users based on phone' do
    end

    it 'correctly adds phone numbers' do
    end

    it 'correctly adds addresses' do
    end
  end
end
