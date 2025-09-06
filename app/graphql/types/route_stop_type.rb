# frozen_string_literal: true

module Types
  class RouteStopType < Types::BaseObject
    field :id, ID, null: false
    field :stop_order, Integer, null: false
    field :estimated_arrival, GraphQL::Types::ISO8601DateTime, null: false
    field :estimated_departure, GraphQL::Types::ISO8601DateTime, null: true
    field :actual_arrival, GraphQL::Types::ISO8601DateTime, null: true
    field :actual_departure, GraphQL::Types::ISO8601DateTime, null: true

    # Associations
    field :route, Types::RouteType, null: false
    field :appointment, Types::AppointmentType, null: false

    # Computed fields
    field :service_duration_minutes, Integer, null: false
    field :buffer_time_minutes, Integer, null: true
    field :on_time, Boolean, null: true
    field :delayed, Boolean, null: false
    field :delay_minutes, Integer, null: false

    def service_duration_minutes
      object.appointment.service_type.duration_minutes
    end

    def buffer_time_minutes
      buffer_seconds = object.buffer_time
      buffer_seconds ? (buffer_seconds / 60).round : nil
    end

    def on_time
      object.on_time?
    end

    def delayed
      object.delayed?
    end
  end
end
