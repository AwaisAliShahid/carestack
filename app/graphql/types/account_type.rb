# frozen_string_literal: true

module Types
  class AccountType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :email, String, null: false
    field :phone, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :vertical, Types::VerticalType, null: false
    field :customers, [Types::CustomerType], null: false
    field :staff, [Types::StaffType], null: false

    # Computed fields
    field :display_name_with_vertical, String, null: false
    field :total_customers, Integer, null: false
    field :total_staff, Integer, null: false

    # Business logic fields
    field :cleaning, Boolean, null: false
    field :elderly_care, Boolean, null: false
    field :requires_background_checks, Boolean, null: false

    def cleaning
      object.cleaning?
    end

    def elderly_care
      object.elderly_care?
    end

    def requires_background_checks
      object.requires_background_checks?
    end
  end
end