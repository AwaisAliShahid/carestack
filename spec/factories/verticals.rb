# frozen_string_literal: true

FactoryBot.define do
  factory :vertical do
    sequence(:name) { |n| "Vertical #{n}" }
    sequence(:slug) { |n| "vertical_#{n}" }
    description { "A service vertical" }
    active { true }

    trait :cleaning do
      name { "Cleaning Services" }
      slug { "cleaning" }
      description { "Professional cleaning services for homes and businesses" }
    end

    trait :elderly_care do
      name { "Elderly Care" }
      slug { "elderly_care" }
      description { "In-home care services for seniors" }
    end

    trait :tutoring do
      name { "Tutoring" }
      slug { "tutoring" }
      description { "Educational tutoring services" }
    end

    trait :home_repair do
      name { "Home Repair" }
      slug { "home_repair" }
      description { "Home maintenance and repair services" }
    end

    trait :inactive do
      active { false }
    end
  end
end
