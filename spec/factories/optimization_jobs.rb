FactoryBot.define do
  factory :optimization_job do
    account { nil }
    requested_date { "2025-09-04" }
    status { "MyString" }
    parameters { "" }
    result { "" }
    processing_started_at { "2025-09-04 12:56:06" }
    processing_completed_at { "2025-09-04 12:56:06" }
  end
end
