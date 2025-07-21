FactoryBot.define do
  factory :photo do
    association :user
    title { Faker::Lorem.words(number: 3).join(' ').titleize }
    description { Faker::Lorem.paragraph }
    taken_at { Faker::Date.between(from: 1.year.ago, to: Date.current) }
    location { Faker::Address.city }

    # Attach a test image file
    after(:build) do |photo|
      photo.image.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.jpg')),
        filename: 'test_image.jpg',
        content_type: 'image/jpeg'
      )
    end

    trait :with_long_description do
      description { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    end

    trait :recent do
      taken_at { 1.day.ago }
    end

    trait :old do
      taken_at { 1.year.ago }
    end
  end
end