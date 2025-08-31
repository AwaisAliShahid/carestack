# frozen_string_literal: true

module Types
  class AppointmentType < Types::BaseObject
    field :id, ID, null: false
    field :account_id, Integer, null: false
    field :customer_id, Integer, null: false
    field :service_type_id, Integer, null: false
    field :staff_id, Integer, null: false
    field :scheduled_at, GraphQL::Types::ISO8601DateTime
    field :duration_minutes, Integer
    field :status, String
    field :notes, String
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
