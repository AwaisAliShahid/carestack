FactoryBot.define do
  factory :service_type do
    name { "MyString" }
    vertical { nil }
    duration_minutes { 1 }
    requires_background_check { false }
    min_staff_ratio { "9.99" }
  end
end
