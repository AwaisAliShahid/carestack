FactoryBot.define do
  factory :route do
    account { nil }
    scheduled_date { "2025-09-04" }
    status { "MyString" }
    total_distance_meters { 1 }
    total_duration_seconds { 1 }
  end
end
