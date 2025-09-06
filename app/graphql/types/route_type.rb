# frozen_string_literal: true

module Types
  class RouteType < Types::BaseObject
    field :id, ID, null: false
    field :scheduled_date, GraphQL::Types::ISO8601Date, null: false
    field :status, String, null: false
    field :total_distance_meters, Integer, null: false
    field :total_duration_seconds, Integer, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :account, Types::AccountType, null: false
    field :route_stops, [ Types::RouteStopType ], null: false
    field :appointments, [ Types::AppointmentType ], null: false

    # Computed fields
    field :total_distance_km, Float, null: false
    field :total_duration_hours, Float, null: false
    field :estimated_fuel_cost, Float, null: false do
      argument :cost_per_km, Float, required: false, default_value: 0.15
    end
    field :staff_member, Types::StaffType, null: true

    def estimated_fuel_cost(cost_per_km:)
      object.estimated_fuel_cost(cost_per_km)
    end
  end
end
