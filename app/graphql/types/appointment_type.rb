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

    # Associations - use dataloader to avoid N+1
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

    # Batch load account to avoid N+1
    def account
      dataloader.with(Sources::RecordSource, Account).load(object.account_id)
    end

    # Batch load customer to avoid N+1
    def customer
      return nil unless object.customer_id

      dataloader.with(Sources::RecordSource, Customer).load(object.customer_id)
    end

    # Batch load service_type to avoid N+1
    def service_type
      dataloader.with(Sources::RecordSource, ServiceType).load(object.service_type_id)
    end

    # Batch load staff to avoid N+1
    def staff
      return nil unless object.staff_id

      dataloader.with(Sources::RecordSource, Staff).load(object.staff_id)
    end

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
      # Batch load account, then batch load its vertical
      dataloader.with(Sources::RecordSource, Account).load(object.account_id).then do |acct|
        dataloader.with(Sources::RecordSource, Vertical).load(acct.vertical_id).then(&:display_name)
      end
    end

    def requires_compliance
      # Batch load account, then batch load its vertical
      dataloader.with(Sources::RecordSource, Account).load(object.account_id).then do |acct|
        dataloader.with(Sources::RecordSource, Vertical).load(acct.vertical_id).then(&:requires_compliance_tracking?)
      end
    end
  end
end
