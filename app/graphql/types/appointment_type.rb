# frozen_string_literal: true

module Types
  class AppointmentType < Types::BaseObject
    field :id, ID, null: false
    field :scheduled_at, GraphQL::Types::ISO8601DateTime, null: false
    field :duration_minutes, Integer, null: false
    field :status, String, null: false
    field :notes, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :account, Types::AccountType, null: false
    field :customer, Types::CustomerType, null: true
    field :service_type, Types::ServiceType, null: false
    field :staff, Types::StaffType, null: true

    # Computed fields
    field :duration_in_hours, String, null: false
    field :end_time, GraphQL::Types::ISO8601DateTime, null: false
    field :is_today, Boolean, null: false
    field :estimated_cost, Float, null: false do
      argument :hourly_rate, Float, required: false, default_value: 50.0
    end

    # Business logic fields
    field :vertical_name, String, null: false
    field :requires_compliance, Boolean, null: false

    def duration_in_hours
      hours = object.duration_minutes / 60.0
      if hours == hours.to_i
        "#{hours.to_i}h"
      else
        "#{hours}h"
      end
    end

    def end_time
      object.scheduled_at + object.duration_minutes.minutes
    end

    def is_today
      object.scheduled_at.to_date == Date.current
    end

    def estimated_cost(hourly_rate:)
      (object.duration_minutes / 60.0 * hourly_rate).round(2)
    end

    def vertical_name
      object.account.vertical.display_name
    end

    def requires_compliance
      object.account.vertical.requires_compliance_tracking?
    end
  end
end