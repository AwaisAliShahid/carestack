# frozen_string_literal: true

FactoryBot.define do
  factory :route_stop do
    route
    appointment
    sequence(:stop_order) { |n| n }
    estimated_arrival { Time.current + 9.hours }
    estimated_departure { Time.current + 11.hours }
    actual_arrival { nil }
    actual_departure { nil }

    trait :first_stop do
      stop_order { 0 }
    end

    trait :on_time do
      actual_arrival { estimated_arrival }
      actual_departure { estimated_departure }
    end

    trait :arrived_early do
      actual_arrival { estimated_arrival - 10.minutes }
    end

    trait :arrived_late do
      actual_arrival { estimated_arrival + 30.minutes }
    end

    trait :significantly_delayed do
      actual_arrival { estimated_arrival + 1.hour }
    end

    trait :completed do
      actual_arrival { estimated_arrival + rand(-5..5).minutes }
      actual_departure { estimated_departure + rand(-5..10).minutes }
    end

    trait :in_progress do
      actual_arrival { Time.current }
      actual_departure { nil }
    end
  end
end
