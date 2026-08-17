FactoryBot.define do
  factory :album_access_session do
    association :album
    sequence(:session_token) { |n| "#{SecureRandom.urlsafe_base64(24)}-#{n}" }
    ip_address { Faker::Internet.ip_v4_address }
    expires_at { AlbumAccessSession::SESSION_DURATION.from_now }
    accessed_at { Time.current }

    trait :expired do
      expires_at { 1.hour.ago }
      accessed_at { 1.hour.ago }
    end
  end
end
