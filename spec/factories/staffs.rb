# frozen_string_literal: true

FactoryBot.define do
  factory :staff do
    account
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    sequence(:email) { |n| "staff#{n}@example.com" }
    phone { "555-#{rand(100..999)}-#{rand(1000..9999)}" }
    background_check_passed { false }

    # Edmonton area home location
    home_latitude { 53.5 + rand(-0.1..0.1) }
    home_longitude { -113.5 + rand(-0.1..0.1) }
    max_travel_radius_km { 25 }

    trait :background_checked do
      background_check_passed { true }
    end

    trait :not_background_checked do
      background_check_passed { false }
    end

    trait :downtown_based do
      home_latitude { 53.5461 }
      home_longitude { -113.4938 }
    end

    trait :west_based do
      home_latitude { 53.5232 }
      home_longitude { -113.5263 }
    end

    trait :limited_radius do
      max_travel_radius_km { 10 }
    end

    trait :wide_radius do
      max_travel_radius_km { 50 }
    end
  end
end
