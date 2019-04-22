FactoryBot.define do
  factory :subscription do
    factory :calling_subscription do
      id { Subscription::CALLING_SUBSCRIPTION }
      name { 'Calling' }
      slug { 'default:calling' }
    end
    factory :email_subscription do
      id { Subscription::EMAIL_SUBSCRIPTION }
      name { 'Email' }
      slug { 'default:email' }
    end
  end
end
