# frozen_string_literal: true

module Authorize
  extend ActiveSupport::Concern

  class AuthenticationError < GraphQL::ExecutionError
    def initialize(message = "You must be logged in to perform this action")
      super(message)
    end
  end

  class AuthorizationError < GraphQL::ExecutionError
    def initialize(message = "You are not authorized to perform this action")
      super(message)
    end
  end

  private

  def current_user
    context[:current_user]
  end

  def authenticate!
    raise AuthenticationError unless current_user
  end

  def authorize_account_access!(account_id)
    authenticate!
    account = Account.find_by(id: account_id)

    unless account && can_access_account?(account)
      raise AuthorizationError, "You do not have access to this account"
    end

    account
  end

  def can_access_account?(account)
    return false unless current_user

    # Admins without an account can access all accounts (super admin)
    return true if current_user.admin? && current_user.account_id.nil?

    # Users can only access their own account
    current_user.account_id == account.id
  end

  def authorize_manager!
    authenticate!

    unless current_user.can_manage_account?
      raise AuthorizationError, "You must be a manager or admin to perform this action"
    end
  end
end
