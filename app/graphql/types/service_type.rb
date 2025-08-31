# frozen_string_literal: true

module Types
  class ServiceType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :duration_minutes, Integer, null: false
    field :requires_background_check, Boolean, null: false
    field :min_staff_ratio, Float, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :vertical, Types::VerticalType, null: false

    # Business logic fields
    field :display_name, String, null: false
    field :duration_in_hours, String, null: false
    field :estimated_cost, Float, null: false do
      argument :hourly_rate, Float, required: false, default_value: 50.0
    end
    field :requires_multiple_staff, Boolean, null: false
    field :compliance_requirements, [String], null: false

    # Delegated methods
    def estimated_cost(hourly_rate:)
      object.estimated_cost(hourly_rate)
    end
  end
end