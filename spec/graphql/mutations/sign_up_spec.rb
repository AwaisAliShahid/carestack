# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::SignUp, type: :request do
  def execute_mutation(email:, password:, password_confirmation:, first_name:, last_name:, account_id: nil)
    query = <<~GRAPHQL
      mutation SignUp(
        $email: String!,
        $password: String!,
        $passwordConfirmation: String!,
        $firstName: String!,
        $lastName: String!,
        $accountId: ID
      ) {
        signUp(
          email: $email,
          password: $password,
          passwordConfirmation: $passwordConfirmation,
          firstName: $firstName,
          lastName: $lastName,
          accountId: $accountId
        ) {
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

    variables = {
      email: email,
      password: password,
      passwordConfirmation: password_confirmation,
      firstName: first_name,
      lastName: last_name,
      accountId: account_id
    }

    post "/graphql", params: { query: query, variables: variables }
    JSON.parse(response.body)
  end

  describe "successful sign up" do
    it "creates a new user and returns a token" do
      result = execute_mutation(
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "John",
        last_name: "Doe"
      )

      expect(result["data"]["signUp"]["errors"]).to be_empty
      expect(result["data"]["signUp"]["authPayload"]["token"]).to be_present
      expect(result["data"]["signUp"]["authPayload"]["user"]["email"]).to eq("newuser@example.com")
      expect(result["data"]["signUp"]["authPayload"]["user"]["firstName"]).to eq("John")
      expect(result["data"]["signUp"]["authPayload"]["user"]["lastName"]).to eq("Doe")
      expect(result["data"]["signUp"]["authPayload"]["user"]["role"]).to eq("member")
    end

    it "creates the user in the database" do
      expect {
        execute_mutation(
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "John",
          last_name: "Doe"
        )
      }.to change(User, :count).by(1)
    end

    it "returns a valid JWT token" do
      result = execute_mutation(
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "John",
        last_name: "Doe"
      )

      token = result["data"]["signUp"]["authPayload"]["token"]
      user = JwtService.user_from_token(token)

      expect(user.email).to eq("newuser@example.com")
    end

    it "sets initial sign in tracking" do
      execute_mutation(
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "John",
        last_name: "Doe"
      )

      user = User.find_by(email: "newuser@example.com")
      expect(user.sign_in_count).to eq(1)
      expect(user.current_sign_in_at).to be_present
    end

    context "with account association" do
      let(:account) { create(:account) }

      it "associates user with the account" do
        result = execute_mutation(
          email: "newuser@example.com",
          password: "password123",
          password_confirmation: "password123",
          first_name: "John",
          last_name: "Doe",
          account_id: account.id.to_s
        )

        expect(result["data"]["signUp"]["errors"]).to be_empty

        user = User.find_by(email: "newuser@example.com")
        expect(user.account).to eq(account)
      end
    end
  end

  describe "failed sign up" do
    it "returns error for password mismatch" do
      result = execute_mutation(
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "differentpassword",
        first_name: "John",
        last_name: "Doe"
      )

      expect(result["data"]["signUp"]["authPayload"]).to be_nil
      expect(result["data"]["signUp"]["errors"]).to include("Password confirmation doesn't match")
    end

    it "returns error for duplicate email" do
      create(:user, email: "existing@example.com")

      result = execute_mutation(
        email: "existing@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "John",
        last_name: "Doe"
      )

      expect(result["data"]["signUp"]["authPayload"]).to be_nil
      expect(result["data"]["signUp"]["errors"]).to include("Email has already been taken")
    end

    it "returns error for short password" do
      result = execute_mutation(
        email: "newuser@example.com",
        password: "short",
        password_confirmation: "short",
        first_name: "John",
        last_name: "Doe"
      )

      expect(result["data"]["signUp"]["authPayload"]).to be_nil
      expect(result["data"]["signUp"]["errors"]).to include("Password is too short (minimum is 6 characters)")
    end

    it "returns error for invalid account_id" do
      result = execute_mutation(
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "John",
        last_name: "Doe",
        account_id: "999999"
      )

      expect(result["data"]["signUp"]["authPayload"]).to be_nil
      expect(result["data"]["signUp"]["errors"]).to include("Account not found")
    end

    it "does not create user on validation failure" do
      expect {
        execute_mutation(
          email: "newuser@example.com",
          password: "short",
          password_confirmation: "short",
          first_name: "John",
          last_name: "Doe"
        )
      }.not_to change(User, :count)
    end
  end
end
