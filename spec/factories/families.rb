FactoryBot.define do
  factory :family do
    association :created_by, factory: :user
    name { Faker::Name.last_name + " Family" }
    description { Faker::Lorem.paragraph }

    trait :with_members do
      after(:create) do |family|
        create_list(:family_membership, 3, family: family)
      end
    end
  end
end
