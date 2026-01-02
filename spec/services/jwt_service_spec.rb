# frozen_string_literal: true

require "rails_helper"

RSpec.describe JwtService do
  let(:user) { create(:user) }

  describe ".encode" do
    it "encodes a payload into a JWT token" do
      token = described_class.encode({ user_id: user.id })
      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3) # JWT has 3 parts
    end

    it "includes expiration time in payload" do
      token = described_class.encode({ user_id: user.id })
      payload = described_class.decode(token)
      expect(payload[:exp]).to be_present
    end

    it "includes issued at time in payload" do
      token = described_class.encode({ user_id: user.id })
      payload = described_class.decode(token)
      expect(payload[:iat]).to be_present
    end

    it "allows custom expiration" do
      token = described_class.encode({ user_id: user.id }, expiration: 1.hour)
      payload = described_class.decode(token)
      expect(payload[:exp]).to be < (Time.current + 2.hours).to_i
    end
  end

  describe ".decode" do
    it "decodes a valid token" do
      token = described_class.encode({ user_id: user.id, custom: "data" })
      payload = described_class.decode(token)

      expect(payload[:user_id]).to eq(user.id)
      expect(payload[:custom]).to eq("data")
    end

    it "raises AuthenticationError for expired token" do
      token = described_class.encode({ user_id: user.id }, expiration: -1.hour)

      expect {
        described_class.decode(token)
      }.to raise_error(JwtService::AuthenticationError, "Token has expired")
    end

    it "raises AuthenticationError for invalid token" do
      expect {
        described_class.decode("invalid.token.here")
      }.to raise_error(JwtService::AuthenticationError, /Invalid token/)
    end

    it "raises AuthenticationError for tampered token" do
      token = described_class.encode({ user_id: user.id })
      tampered_token = token[0..-5] + "xxxx"

      expect {
        described_class.decode(tampered_token)
      }.to raise_error(JwtService::AuthenticationError, /Invalid token/)
    end
  end

  describe ".token_for_user" do
    it "generates a token with user information" do
      token = described_class.token_for_user(user)
      payload = described_class.decode(token)

      expect(payload[:user_id]).to eq(user.id)
      expect(payload[:email]).to eq(user.email)
      expect(payload[:role]).to eq(user.role)
    end

    it "includes account_id when user has an account" do
      account = create(:account)
      user_with_account = create(:user, account: account)

      token = described_class.token_for_user(user_with_account)
      payload = described_class.decode(token)

      expect(payload[:account_id]).to eq(account.id)
    end

    it "has nil account_id when user has no account" do
      token = described_class.token_for_user(user)
      payload = described_class.decode(token)

      expect(payload[:account_id]).to be_nil
    end
  end

  describe ".user_from_token" do
    it "returns the user for a valid token" do
      token = described_class.token_for_user(user)
      result = described_class.user_from_token(token)

      expect(result).to eq(user)
    end

    it "returns nil for blank token" do
      expect(described_class.user_from_token(nil)).to be_nil
      expect(described_class.user_from_token("")).to be_nil
    end

    it "returns nil for invalid token" do
      expect(described_class.user_from_token("invalid.token")).to be_nil
    end

    it "returns nil for expired token" do
      token = described_class.encode({ user_id: user.id }, expiration: -1.hour)
      expect(described_class.user_from_token(token)).to be_nil
    end

    it "returns nil if user no longer exists" do
      token = described_class.token_for_user(user)
      user.destroy

      expect(described_class.user_from_token(token)).to be_nil
    end
  end
end
