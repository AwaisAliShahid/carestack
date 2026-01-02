# frozen_string_literal: true

FactoryBot.define do
  factory :service_type do
    sequence(:name) { |n| "Service Type #{n}" }
    vertical
    duration_minutes { 120 }
    requires_background_check { false }
    min_staff_ratio { nil }

    # Cleaning service types
    trait :basic_cleaning do
      association :vertical, :cleaning
      name { "Basic House Cleaning" }
      duration_minutes { 120 }
      requires_background_check { false }
    end

    trait :deep_cleaning do
      association :vertical, :cleaning
      name { "Deep Cleaning" }
      duration_minutes { 240 }
      requires_background_check { false }
    end

    trait :post_construction do
      association :vertical, :cleaning
      name { "Post-Construction Cleanup" }
      duration_minutes { 300 }
      requires_background_check { true }
    end

    # Elderly care service types
    trait :companion_care do
      association :vertical, :elderly_care
      name { "Companion Care" }
      duration_minutes { 240 }
      requires_background_check { true }
      min_staff_ratio { 1.0 }
    end

    trait :personal_care do
      association :vertical, :elderly_care
      name { "Personal Care Assistance" }
      duration_minutes { 120 }
      requires_background_check { true }
      min_staff_ratio { 1.0 }
    end

    trait :full_day_care do
      association :vertical, :elderly_care
      name { "24-Hour Care" }
      duration_minutes { 1440 }
      requires_background_check { true }
      min_staff_ratio { 2.0 }
    end

    # Tutoring service types
    trait :elementary_tutoring do
      association :vertical, :tutoring
      name { "Elementary Tutoring" }
      duration_minutes { 60 }
      requires_background_check { true }
    end

    trait :high_school_tutoring do
      association :vertical, :tutoring
      name { "High School Math" }
      duration_minutes { 90 }
      requires_background_check { true }
    end

    # Generic traits
    trait :requires_background_check do
      requires_background_check { true }
    end

    trait :multi_staff_required do
      min_staff_ratio { 2.0 }
    end

    trait :short_duration do
      duration_minutes { 30 }
    end

    trait :long_duration do
      duration_minutes { 480 }
    end
  end
end
