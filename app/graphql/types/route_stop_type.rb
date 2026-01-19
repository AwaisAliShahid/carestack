# frozen_string_literal: true

module Types
  class RouteStopType < Types::BaseObject
    field :id, ID, null: false
    field :stop_order, Integer, null: false
    field :estimated_arrival, GraphQL::Types::ISO8601DateTime, null: false
    field :estimated_departure, GraphQL::Types::ISO8601DateTime, null: true
    field :actual_arrival, GraphQL::Types::ISO8601DateTime, null: true
    field :actual_departure, GraphQL::Types::ISO8601DateTime, null: true

    # Associations - use dataloader to avoid N+1
    field :route, Types::RouteType, null: false
    field :appointment, Types::AppointmentType, null: false

    # Computed fields
    field :service_duration_minutes, Integer, null: false
    field :buffer_time_minutes, Integer, null: true
    field :on_time, Boolean, null: true
    field :delayed, Boolean, null: false
    field :delay_minutes, Integer, null: false

    # Batch load route to avoid N+1
    def route
      dataloader.with(Sources::RecordSource, Route).load(object.route_id)
    end

    # Batch load appointment to avoid N+1
    def appointment
      dataloader.with(Sources::RecordSource, Appointment).load(object.appointment_id)
    end

    def service_duration_minutes
      # Batch load appointment, then batch load its service_type
      dataloader.with(Sources::RecordSource, Appointment).load(object.appointment_id).then do |appt|
        dataloader.with(Sources::RecordSource, ServiceType).load(appt.service_type_id).then(&:duration_minutes)
      end
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
