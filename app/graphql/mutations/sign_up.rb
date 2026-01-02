# frozen_string_literal: true

module Mutations
  class SignUp < BaseMutation
    description "Register a new user account"

    argument :email, String, required: true
    argument :password, String, required: true
    argument :password_confirmation, String, required: true
    argument :first_name, String, required: true
    argument :last_name, String, required: true
    argument :account_id, ID, required: false, description: "Associate user with an existing account"

    field :auth_payload, Types::AuthPayloadType, null: true
    field :errors, [ String ], null: false

    def resolve(email:, password:, password_confirmation:, first_name:, last_name:, account_id: nil)
      # Check password confirmation
      if password != password_confirmation
        return {
          auth_payload: nil,
          errors: [ "Password confirmation doesn't match" ]
        }
      end

      # Find account if provided
      account = nil
      if account_id.present?
        account = Account.find_by(id: account_id)
        unless account
          return {
            auth_payload: nil,
            errors: [ "Account not found" ]
          }
        end
      end

      # Create user
      user = User.new(
        email: email.downcase,
        password: password,
        password_confirmation: password_confirmation,
        first_name: first_name,
        last_name: last_name,
        account: account,
        role: "member"
      )

      if user.save
        # Set initial sign in tracking
        user.update(
          sign_in_count: 1,
          current_sign_in_at: Time.current,
          current_sign_in_ip: context[:remote_ip]
        )

        token = JwtService.token_for_user(user)

        {
          auth_payload: {
            token: token,
            user: user
          },
          errors: []
        }
      else
        {
          auth_payload: nil,
          errors: user.errors.full_messages
        }
      end
    end
  end
end
