# frozen_string_literal: true

module Types
  class AuthPayloadType < Types::BaseObject
    description "Authentication response with JWT token and user info"

    field :token, String, null: false, description: "JWT authentication token"
    field :user, Types::UserType, null: false, description: "Authenticated user"
  end
end
