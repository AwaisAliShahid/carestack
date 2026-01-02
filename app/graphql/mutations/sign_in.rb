# frozen_string_literal: true

module Mutations
  class SignIn < BaseMutation
    description "Authenticate a user and return a JWT token"

    argument :email, String, required: true
    argument :password, String, required: true

    field :auth_payload, Types::AuthPayloadType, null: true
    field :errors, [String], null: false

    def resolve(email:, password:)
      user = User.find_by(email: email.downcase)

      if user.nil?
        return {
          auth_payload: nil,
          errors: ["Invalid email or password"]
        }
      end

      unless user.valid_password?(password)
        return {
          auth_payload: nil,
          errors: ["Invalid email or password"]
        }
      end

      # Update Devise trackable fields
      user.update(
        sign_in_count: user.sign_in_count + 1,
        current_sign_in_at: Time.current,
        last_sign_in_at: user.current_sign_in_at,
        current_sign_in_ip: context[:remote_ip],
        last_sign_in_ip: user.current_sign_in_ip
      )

      token = JwtService.token_for_user(user)

      {
        auth_payload: {
          token: token,
          user: user
        },
        errors: []
      }
    end
  end
end
