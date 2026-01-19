# frozen_string_literal: true

module GraphqlHelpers
  def execute_graphql(query, variables: {}, context: {}, current_user: nil)
    context = context.merge(current_user: current_user) if current_user
    CarestackSchema.execute(
      query,
      variables: variables,
      context: context
    )
  end

  def graphql_errors(result)
    result["errors"]&.map { |e| e["message"] }
  end

  def graphql_data(result, *keys)
    result.dig("data", *keys)
  end
end

RSpec.configure do |config|
  config.include GraphqlHelpers, type: :graphql
end
