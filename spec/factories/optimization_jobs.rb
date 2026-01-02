# frozen_string_literal: true

FactoryBot.define do
  factory :optimization_job do
    account
    requested_date { Date.current }
    status { "pending" }
    parameters { { optimization_type: "minimize_travel_time", appointment_count: 5, staff_count: 2 } }
    result { nil }
    processing_started_at { nil }
    processing_completed_at { nil }

    trait :pending do
      status { "pending" }
      processing_started_at { nil }
      processing_completed_at { nil }
    end

    trait :processing do
      status { "processing" }
      processing_started_at { 1.minute.ago }
      processing_completed_at { nil }
    end

    trait :completed do
      status { "completed" }
      processing_started_at { 2.minutes.ago }
      processing_completed_at { 1.minute.ago }
      result do
        {
          "routes_created" => 2,
          "total_appointments" => 5,
          "time_saved_hours" => 1.5,
          "cost_savings" => 37.50,
          "efficiency_improvement" => 25.0,
          "optimization_metrics" => {
            "total_distance_km" => 45.2,
            "average_route_duration" => 3600,
            "appointments_per_route" => 2.5
          }
        }
      end
    end

    trait :failed do
      status { "failed" }
      processing_started_at { 2.minutes.ago }
      processing_completed_at { 1.minute.ago }
      result { { "error" => "No appointments found for optimization" } }
    end

    trait :minimize_travel_time do
      parameters { { optimization_type: "minimize_travel_time", appointment_count: 5, staff_count: 2 } }
    end

    trait :minimize_cost do
      parameters { { optimization_type: "minimize_total_cost", appointment_count: 5, staff_count: 2 } }
    end

    trait :balance_workload do
      parameters { { optimization_type: "balance_workload", appointment_count: 5, staff_count: 2 } }
    end

    trait :recent do
      created_at { 1.day.ago }
    end

    trait :old do
      created_at { 2.weeks.ago }
    end
  end
end
