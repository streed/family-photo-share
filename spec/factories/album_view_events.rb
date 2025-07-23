FactoryBot.define do
  factory :album_view_event do
    album
    event_type { "password_entry" }
    photo { nil }
    ip_address { Faker::Internet.ip_v4_address }
    user_agent { Faker::Internet.user_agent }
    referrer { Faker::Internet.url }
    session_id { SecureRandom.hex(16) }
    occurred_at { Time.current }
    
    trait :password_entry do
      event_type { "password_entry" }
      photo { nil }
    end
    
    trait :password_attempt_failed do
      event_type { "password_attempt_failed" }
      photo { nil }
    end
    
    trait :photo_view do
      event_type { "photo_view" }
      photo
    end
    
    trait :old do
      occurred_at { 10.days.ago }
    end
    
    trait :recent do
      occurred_at { 2.days.ago }
    end
  end
end
