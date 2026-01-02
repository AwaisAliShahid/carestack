# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::SignIn, type: :request do
  let(:user) { create(:user, email: "test@example.com", password: "password123") }

  def execute_mutation(email:, password:)
    query = <<~GRAPHQL
      mutation SignIn($email: String!, $password: String!) {
        signIn(email: $email, password: $password) {
          authPayload {
            token
            user {
              id
              email
              firstName
              lastName
              role
            }
          }
          errors
        }
      }
    GRAPHQL

    post "/graphql", params: { query: query, variables: { email: email, password: password } }
    JSON.parse(response.body)
  end

  describe "successful sign in" do
    before { user } # ensure user exists

    it "returns a JWT token and user info" do
      result = execute_mutation(email: "test@example.com", password: "password123")

      expect(result["data"]["signIn"]["errors"]).to be_empty
      expect(result["data"]["signIn"]["authPayload"]["token"]).to be_present
      expect(result["data"]["signIn"]["authPayload"]["user"]["email"]).to eq("test@example.com")
    end

    it "returns a valid JWT token" do
      result = execute_mutation(email: "test@example.com", password: "password123")

      token = result["data"]["signIn"]["authPayload"]["token"]
      decoded_user = JwtService.user_from_token(token)

      expect(decoded_user).to eq(user)
    end

    it "updates sign in tracking" do
      execute_mutation(email: "test@example.com", password: "password123")
      user.reload

      expect(user.sign_in_count).to eq(1)
      expect(user.current_sign_in_at).to be_present
    end

    it "is case insensitive for email" do
      result = execute_mutation(email: "TEST@EXAMPLE.COM", password: "password123")

      expect(result["data"]["signIn"]["errors"]).to be_empty
      expect(result["data"]["signIn"]["authPayload"]["token"]).to be_present
    end
  end

  describe "failed sign in" do
    before { user }

    it "returns error for non-existent email" do
      result = execute_mutation(email: "wrong@example.com", password: "password123")

      expect(result["data"]["signIn"]["authPayload"]).to be_nil
      expect(result["data"]["signIn"]["errors"]).to include("Invalid email or password")
    end

    it "returns error for wrong password" do
      result = execute_mutation(email: "test@example.com", password: "wrongpassword")

      expect(result["data"]["signIn"]["authPayload"]).to be_nil
      expect(result["data"]["signIn"]["errors"]).to include("Invalid email or password")
    end

    it "does not update sign in tracking on failure" do
      execute_mutation(email: "test@example.com", password: "wrongpassword")
      user.reload

      expect(user.sign_in_count).to eq(0)
    end
  end
end
