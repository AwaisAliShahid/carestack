# frozen_string_literal: true

FactoryBot.define do
  factory :customer do
    account
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    sequence(:email) { |n| "customer#{n}@example.com" }
    phone { "555-#{rand(100..999)}-#{rand(1000..9999)}" }
    address { Faker::Address.full_address }

    # Edmonton area coordinates
    latitude { 53.5 + rand(-0.1..0.1) }
    longitude { -113.5 + rand(-0.1..0.1) }
    geocoded_address { "#{address}, Edmonton, AB, Canada" }

    trait :downtown do
      latitude { 53.5461 }
      longitude { -113.4938 }
      address { "Downtown Edmonton" }
    end

    trait :west_edmonton do
      latitude { 53.5232 }
      longitude { -113.5263 }
      address { "West Edmonton" }
    end

    trait :south_edmonton do
      latitude { 53.4668 }
      longitude { -113.5114 }
      address { "South Edmonton" }
    end

    trait :without_location do
      latitude { nil }
      longitude { nil }
      geocoded_address { nil }
    end
  end
end
