FactoryBot.define do
  factory :bulk_upload do
    association :user
    association :album
    status { 'pending' }
    total_count { 5 }
    processed_count { 0 }
    failed_count { 0 }
    error_messages { nil }

    trait :processing do
      status { 'processing' }
      processed_count { 2 }
    end

    trait :completed do
      status { 'completed' }
      processed_count { 5 }
    end

    trait :failed do
      status { 'failed' }
      failed_count { 5 }
      error_messages { "Error processing files" }
    end

    trait :partial do
      status { 'partial' }
      processed_count { 3 }
      failed_count { 2 }
      error_messages { "Some files failed to process" }
    end

    trait :without_album do
      album { nil }
    end
  end
end
