# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField

    # Add root-level fields type by type.

    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, GraphQL::Types::ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [ Types::NodeType, null: true ], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ GraphQL::Types::ID ], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Our custom fields
    field :verticals, [ Types::VerticalType ], null: false, description: "Get all available verticals"
    field :vertical, Types::VerticalType, null: true, description: "Get a specific vertical" do
      argument :id, GraphQL::Types::ID, required: false
      argument :slug, String, required: false
    end

    field :accounts, [ Types::AccountType ], null: false, description: "Get all accounts"
    field :account, Types::AccountType, null: true, description: "Get a specific account" do
      argument :id, GraphQL::Types::ID, required: true
    end

    field :service_types, [ Types::ServiceType ], null: false, description: "Get all service types"
    field :service_types_for_vertical, [ Types::ServiceType ], null: false, description: "Get service types for a specific vertical" do
      argument :vertical_id, GraphQL::Types::ID, required: true
    end

    # Resolver methods
    def verticals
      Vertical.active
    end

    def vertical(id: nil, slug: nil)
      if id
        Vertical.find_by(id: id)
      elsif slug
        Vertical.find_by(slug: slug)
      else
        raise GraphQL::ExecutionError, "Must provide either id or slug"
      end
    end

    def accounts
      Account.all
    end

    def account(id:)
      Account.find_by(id: id)
    end

    def service_types
      ServiceType.all
    end

    def service_types_for_vertical(vertical_id:)
      ServiceType.where(vertical_id: vertical_id)
    end
  end
end
