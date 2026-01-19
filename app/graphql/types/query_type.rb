# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    include GraphQL::Types::Relay::HasNodeField
    include GraphQL::Types::Relay::HasNodesField
    include Authorize

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

    field :optimization_job, Types::OptimizationJobType, null: true,
          description: "Get optimization job status by ID (useful for polling async jobs)" do
      argument :id, GraphQL::Types::ID, required: true
    end

    field :optimization_jobs, [ Types::OptimizationJobType ], null: false,
          description: "Get optimization jobs for an account" do
      argument :account_id, GraphQL::Types::ID, required: true
      argument :status, String, required: false
      argument :limit, Integer, required: false, default_value: 10
    end

    field :me, Types::UserType, null: true, description: "Get the currently authenticated user"

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
      authenticate!

      # Super admins can see all accounts, regular users only their own
      if current_user.admin? && current_user.account_id.nil?
        Account.all
      elsif current_user.account
        [ current_user.account ]
      else
        []
      end
    end

    def account(id:)
      authorize_account_access!(id)
    end

    def service_types
      ServiceType.all
    end

    def service_types_for_vertical(vertical_id:)
      ServiceType.where(vertical_id: vertical_id)
    end

    def optimization_job(id:)
      authenticate!
      job = OptimizationJob.find_by(id: id)
      return nil unless job

      # Verify user has access to this job's account
      unless can_access_account?(job.account)
        raise Authorize::AuthorizationError, "You do not have access to this optimization job"
      end

      job
    end

    def optimization_jobs(account_id:, status: nil, limit: 10)
      authorize_account_access!(account_id)

      scope = OptimizationJob.where(account_id: account_id).order(created_at: :desc).limit(limit)
      scope = scope.where(status: status) if status.present?
      scope
    end

    def me
      context[:current_user]
    end
  end
end
