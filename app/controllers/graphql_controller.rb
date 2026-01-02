# frozen_string_literal: true

class GraphqlController < ApplicationController
  def execute
    variables = prepare_variables(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {
      current_user: current_user,
      remote_ip: request.remote_ip
    }
    result = CarestackSchema.execute(query, variables: variables, context: context, operation_name: operation_name)
    render json: result
  rescue StandardError => e
    raise e unless Rails.env.development?
    handle_error_in_development(e)
  end

  private

  # Handle variables in form data, JSON body, or a blank value
  def prepare_variables(variables_param)
    case variables_param
    when String
      if variables_param.present?
        JSON.parse(variables_param) || {}
      else
        {}
      end
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby will validate name and type of incoming variables.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(e)
    logger.error e.message
    logger.error e.backtrace.join("\n")

    render json: { errors: [ { message: e.message, backtrace: e.backtrace } ], data: {} }, status: 500
  end

  # Extract JWT from Authorization header and return current user
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = nil
    token = extract_token_from_header

    if token.present?
      @current_user = JwtService.user_from_token(token)
    end

    @current_user
  end

  # Extract Bearer token from Authorization header
  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil if auth_header.blank?

    # Support "Bearer <token>" format
    if auth_header.start_with?("Bearer ")
      auth_header.split(" ").last
    else
      auth_header
    end
  end
end
