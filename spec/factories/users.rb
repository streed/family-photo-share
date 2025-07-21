FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    confirmed_at { Time.current }

    trait :oauth_user do
      provider { 'google_oauth2' }
      uid { Faker::Number.number(digits: 10).to_s }
      password { nil }
      password_confirmation { nil }
    end

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :with_bio do
      bio { Faker::Lorem.paragraph(sentence_count: 2) }
    end

    trait :with_phone do
      phone_number { Faker::PhoneNumber.phone_number }
    end
  end
end