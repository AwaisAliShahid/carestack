# frozen_string_literal: true

module Types
  class StaffType < Types::BaseObject
    field :id, ID, null: false
    field :account_id, Integer, null: false
    field :first_name, String
    field :last_name, String
    field :email, String
    field :phone, String
    field :background_check_passed, Boolean
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
