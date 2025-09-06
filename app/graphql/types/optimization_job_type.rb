# frozen_string_literal: true

module Types
  class OptimizationJobType < Types::BaseObject
    field :id, ID, null: false
    field :requested_date, GraphQL::Types::ISO8601Date, null: false
    field :status, String, null: false
    field :parameters, GraphQL::Types::JSON, null: true
    field :result, GraphQL::Types::JSON, null: true
    field :processing_started_at, GraphQL::Types::ISO8601DateTime, null: true
    field :processing_completed_at, GraphQL::Types::ISO8601DateTime, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :account, Types::AccountType, null: false

    # Computed fields
    field :processing_time_seconds, Integer, null: true
    field :success, Boolean, null: false
    field :failed, Boolean, null: false
    field :processing, Boolean, null: false
    field :time_savings_hours, Float, null: true
    field :cost_savings, Float, null: true
    field :routes_created, Integer, null: false

    def processing_time_seconds
      object.processing_time_seconds&.to_i
    end

    def success
      object.success?
    end

    def failed
      object.failed?
    end

    def processing
      object.processing?
    end

    def time_savings_hours
      object.time_savings
    end

    def cost_savings
      object.cost_savings
    end
  end
end