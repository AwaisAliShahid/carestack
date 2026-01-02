# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    role { "member" }
    account { nil }

    trait :admin do
      role { "admin" }
    end

    trait :manager do
      role { "manager" }
    end

    trait :member do
      role { "member" }
    end

    trait :with_account do
      account
    end

    trait :with_cleaning_account do
      association :account, :cleaning_business
    end
  end
end
