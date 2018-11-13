FactoryBot.define do
  factory :subscription do
    factory :calling_subscription do
      id { Subscription::CALLING_SUBSCRIPTION }
      name { 'Calling' }
    end
    factory :email_subscription do
      id { Subscription::EMAIL_SUBSCRIPTION }
      name { 'Email' }
    end
    factory :tijuana_subscription do
      id { Settings.tijuana.opt_out_subscription_id }
      name { 'Tijuana Calling' }
    end
  end
end
