# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    # Authentication
    field :sign_in, mutation: Mutations::SignIn
    field :sign_up, mutation: Mutations::SignUp

    # Business operations
    field :create_appointment, mutation: Mutations::CreateAppointment
    field :optimize_routes, mutation: Mutations::OptimizeRoutes
  end
end
