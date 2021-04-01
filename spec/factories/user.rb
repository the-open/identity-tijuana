module ExternalSystems::IdentityTijuana
  FactoryBot.define do
    factory :tijuana_user, class: User do
      first_name { Faker::Name.first_name }
      last_name { Faker::Name.last_name }
      email { Faker::Internet.email }
    end
  end
end
