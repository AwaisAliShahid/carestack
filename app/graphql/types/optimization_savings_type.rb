# frozen_string_literal: true

module Types
  class OptimizationSavingsType < Types::BaseObject
    field :time_saved_hours, Float, null: true
    field :cost_savings, Float, null: true
    field :efficiency_improvement_percent, Float, null: true
    field :total_distance_km, Float, null: true
    field :routes_created, Integer, null: true
  end
end