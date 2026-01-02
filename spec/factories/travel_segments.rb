# frozen_string_literal: true

FactoryBot.define do
  factory :travel_segment do
    association :from_appointment, factory: :appointment
    association :to_appointment, factory: :appointment
    distance_meters { 5000 }
    duration_seconds { 600 }
    traffic_factor { 1.0 }

    trait :short_distance do
      distance_meters { 1000 }
      duration_seconds { 180 }
    end

    trait :long_distance do
      distance_meters { 25_000 }
      duration_seconds { 1800 }
    end

    trait :heavy_traffic do
      traffic_factor { 1.5 }
    end

    trait :light_traffic do
      traffic_factor { 0.9 }
    end

    trait :no_traffic_data do
      traffic_factor { nil }
    end
  end
end
