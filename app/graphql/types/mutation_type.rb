# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :create_appointment, mutation: Mutations::CreateAppointment
    field :optimize_routes, mutation: Mutations::OptimizeRoutes
  end
end
