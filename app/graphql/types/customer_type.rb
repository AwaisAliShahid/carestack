# frozen_string_literal: true

module Types
  class CustomerType < Types::BaseObject
    field :id, ID, null: false
    field :first_name, String, null: false
    field :last_name, String, null: false
    field :email, String, null: false
    field :phone, String, null: false
    field :address, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :account, Types::AccountType, null: false

    # Computed fields
    field :full_name, String, null: false

    def full_name
      "#{object.first_name} #{object.last_name}"
    end
  end
end