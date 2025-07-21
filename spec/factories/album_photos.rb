FactoryBot.define do
  factory :album_photo do
    association :album
    association :photo
    position { 1 }
    added_at { Time.current }
  end
end
