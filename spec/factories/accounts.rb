# frozen_string_literal: true

FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Business #{n}" }
    sequence(:email) { |n| "business#{n}@example.com" }
    phone { "555-#{rand(100..999)}-#{rand(1000..9999)}" }
    vertical

    trait :cleaning_business do
      association :vertical, :cleaning
      name { "Sparkle Clean Co." }
    end

    trait :elderly_care_business do
      association :vertical, :elderly_care
      name { "Golden Years Care" }
    end

    trait :tutoring_business do
      association :vertical, :tutoring
      name { "Bright Minds Tutoring" }
    end

    trait :with_staff do
      transient do
        staff_count { 3 }
      end

      after(:create) do |account, evaluator|
        create_list(:staff, evaluator.staff_count, account: account)
      end
    end

    trait :with_customers do
      transient do
        customer_count { 5 }
      end

      after(:create) do |account, evaluator|
        create_list(:customer, evaluator.customer_count, account: account)
      end
    end

    trait :with_full_setup do
      with_staff
      with_customers

      after(:create) do |account|
        ServiceType.create_defaults_for_vertical(account.vertical) if account.vertical.service_types.empty?
      end
    end
  end
end
