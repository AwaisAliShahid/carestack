FactoryBot.define do
  factory :appointment do
    account { nil }
    customer { nil }
    service_type { nil }
    staff { nil }
    scheduled_at { "2025-08-31 14:22:53" }
    duration_minutes { 1 }
    status { "MyString" }
    notes { "MyText" }
  end
end
