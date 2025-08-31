# frozen_string_literal: true

module Types
  class VerticalType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :slug, String, null: false
    field :description, String, null: true
    field :active, Boolean, null: false
    field :display_name, String, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :accounts, [Types::AccountType], null: false
    field :service_types, [Types::ServiceType], null: false

    # Business logic fields
    field :is_cleaning, Boolean, null: false
    field :is_elderly_care, Boolean, null: false
    field :requires_compliance_tracking, Boolean, null: false
    field :requires_background_checks, Boolean, null: false

    # Computed fields
    field :total_accounts, Integer, null: false
    field :total_service_types, Integer, null: false

    def is_cleaning
      object.cleaning?
    end

    def is_elderly_care
      object.elderly_care?
    end

    def requires_compliance_tracking
      object.requires_compliance_tracking?
    end

    def requires_background_checks
      object.requires_background_checks?
    end

    def total_accounts
      object.accounts.count
    end

    def total_service_types
      object.service_types.count
    end
  end
end