# frozen_string_literal: true

class JwtService
  SECRET_KEY = Rails.application.credentials.secret_key_base || ENV.fetch("SECRET_KEY_BASE", "dev-secret-key")
  ALGORITHM = "HS256"
  DEFAULT_EXPIRATION = 24.hours

  class << self
    # Encode a payload into a JWT token
    def encode(payload, expiration: DEFAULT_EXPIRATION)
      payload = payload.dup
      payload[:exp] = expiration.from_now.to_i
      payload[:iat] = Time.current.to_i

      JWT.encode(payload, SECRET_KEY, ALGORITHM)
    end

    # Decode a JWT token and return the payload
    def decode(token)
      decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: ALGORITHM })
      HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::ExpiredSignature
      raise AuthenticationError, "Token has expired"
    rescue JWT::DecodeError => e
      raise AuthenticationError, "Invalid token: #{e.message}"
    end

    # Generate a token for a user
    def token_for_user(user)
      payload = {
        user_id: user.id,
        email: user.email,
        account_id: user.account_id,
        role: user.role
      }

      encode(payload)
    end

    # Extract user from token
    def user_from_token(token)
      return nil if token.blank?

      payload = decode(token)
      User.find_by(id: payload[:user_id])
    rescue AuthenticationError
      nil
    end
  end

  # Custom error class for authentication failures
  class AuthenticationError < StandardError; end
end
