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
    factory :sms_subscription do
      id { Subscription::SMS_SUBSCRIPTION }
      name { 'SMS' }
      slug { 'default:sms' }
    end
  end
end
