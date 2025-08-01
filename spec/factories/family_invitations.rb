FactoryBot.define do
  factory :family_invitation do
    association :family
    association :inviter, factory: :user
    email { Faker::Internet.email }
    status { 'pending' }
    expires_at { 7.days.from_now }

    trait :accepted do
      status { 'accepted' }
    end

    trait :declined do
      status { 'declined' }
    end

    trait :expired do
      status { 'expired' }
      expires_at { 1.day.ago }
    end
  end
end
