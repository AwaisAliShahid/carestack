# frozen_string_literal: true

FactoryBot.define do
  factory :route do
    account
    optimization_job { nil }
    scheduled_date { Date.current }
    status { "pending" }
    total_distance_meters { 15_000 }
    total_duration_seconds { 3600 }

    trait :pending do
      status { "pending" }
    end

    trait :optimized do
      status { "optimized" }
    end

    trait :active do
      status { "active" }
    end

    trait :completed do
      status { "completed" }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :short_route do
      total_distance_meters { 5_000 }
      total_duration_seconds { 1800 }
    end

    trait :long_route do
      total_distance_meters { 50_000 }
      total_duration_seconds { 7200 }
    end

    trait :today do
      scheduled_date { Date.current }
    end

    trait :tomorrow do
      scheduled_date { Date.current + 1.day }
    end

    trait :with_stops do
      transient do
        stop_count { 3 }
      end

      after(:create) do |route, evaluator|
        evaluator.stop_count.times do |i|
          appointment = create(:appointment, account: route.account, scheduled_at: route.scheduled_date.to_time + (9 + i).hours)
          create(:route_stop, route: route, appointment: appointment, stop_order: i)
        end
      end
    end
  end
end
