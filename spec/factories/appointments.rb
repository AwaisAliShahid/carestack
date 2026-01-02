# frozen_string_literal: true

FactoryBot.define do
  factory :appointment do
    account
    customer { association :customer, account: account }
    service_type { association :service_type, vertical: account.vertical }
    staff { association :staff, account: account }
    scheduled_at { 1.day.from_now.beginning_of_day + 9.hours }
    duration_minutes { service_type&.duration_minutes || 120 }
    status { "scheduled" }
    notes { nil }

    trait :scheduled do
      status { "scheduled" }
    end

    trait :confirmed do
      status { "confirmed" }
    end

    trait :in_progress do
      status { "in_progress" }
      scheduled_at { Time.current }
    end

    trait :completed do
      status { "completed" }
      scheduled_at { 1.day.ago }
    end

    trait :cancelled do
      status { "cancelled" }
    end

    trait :today do
      scheduled_at { Time.current.beginning_of_day + 9.hours }
    end

    trait :tomorrow do
      scheduled_at { 1.day.from_now.beginning_of_day + 9.hours }
    end

    trait :morning do
      scheduled_at { |apt| apt.scheduled_at.change(hour: 9) }
    end

    trait :afternoon do
      scheduled_at { |apt| apt.scheduled_at.change(hour: 14) }
    end

    trait :with_notes do
      notes { Faker::Lorem.paragraph }
    end

    # Create an appointment with proper associations for a cleaning business
    trait :cleaning_appointment do
      association :account, :cleaning_business
      after(:build) do |appointment|
        appointment.service_type ||= create(:service_type, :basic_cleaning, vertical: appointment.account.vertical)
      end
    end

    # Create an appointment for elderly care (requires background check)
    trait :elderly_care_appointment do
      association :account, :elderly_care_business
      staff { association :staff, :background_checked, account: account }
      after(:build) do |appointment|
        appointment.service_type ||= create(:service_type, :companion_care, vertical: appointment.account.vertical)
      end
    end
  end
end
