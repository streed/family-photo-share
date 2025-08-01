FactoryBot.define do
  factory :album do
    association :user
    name { Faker::Lorem.words(number: 3).join(' ').titleize }
    description { Faker::Lorem.paragraph }
    privacy { 'private' }
    cover_photo { nil }

    trait :family do
      privacy { 'family' }
    end

    trait :public do
      privacy { 'public' }
    end

    trait :with_photos do
      after(:create) do |album|
        photos = create_list(:photo, 5, user: album.user)
        photos.each_with_index do |photo, index|
          album.add_photo(photo, index + 1)
        end
        album.update!(cover_photo: photos.first)
      end
    end
  end
end
