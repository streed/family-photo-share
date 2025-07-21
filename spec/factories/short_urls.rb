FactoryBot.define do
  factory :short_url do
    token { "MyString" }
    resource_type { "MyString" }
    resource_id { "" }
    variant { "MyString" }
    expires_at { "2025-07-19 15:14:51" }
    accessed_at { "2025-07-19 15:14:51" }
    access_count { 1 }
  end
end
