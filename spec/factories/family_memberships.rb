FactoryBot.define do
  factory :family_membership do
    association :user
    association :family
    role { 'member' }
    joined_at { Time.current }
    
    trait :admin do
      role { 'admin' }
    end
  end
end
