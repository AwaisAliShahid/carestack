# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::OptimizeRoutes, type: :graphql do
  let(:mutation) do
    <<~GQL
      mutation OptimizeRoutes(
        $accountId: ID!
        $date: ISO8601Date!
        $optimizationType: String
        $staffIds: [ID!]
        $forceReoptimization: Boolean
      ) {
        optimizeRoutes(
          accountId: $accountId
          date: $date
          optimizationType: $optimizationType
          staffIds: $staffIds
          forceReoptimization: $forceReoptimization
        ) {
          optimizationJob {
            id
            status
            requestedDate
          }
          routes {
            id
            status
            totalDistanceMeters
            totalDurationSeconds
          }
          estimatedSavings {
            timeSavedHours
            costSavings
            efficiencyImprovementPercent
          }
          errors
        }
      }
    GQL
  end

  describe "successful optimization" do
    let(:vertical) { create(:vertical, :cleaning) }
    let(:account) { create(:account, vertical: vertical) }
    let(:service_type) { create(:service_type, vertical: vertical, duration_minutes: 60) }
    let(:staff) { create(:staff, :downtown_based, account: account) }
    let(:user) { create(:user, account: account) }
    let(:today) { Date.current }

    before do
      customer1 = create(:customer, :downtown, account: account)
      customer2 = create(:customer, :west_edmonton, account: account)

      create(:appointment,
        account: account,
        customer: customer1,
        service_type: service_type,
        staff: staff,
        scheduled_at: today.to_time + 9.hours,
        status: "scheduled"
      )

      create(:appointment,
        account: account,
        customer: customer2,
        service_type: service_type,
        staff: staff,
        scheduled_at: today.to_time + 11.hours,
        status: "scheduled"
      )
    end

    it "creates optimized routes" do
      variables = {
        accountId: account.id.to_s,
        date: today.iso8601
      }

      result = execute_graphql(mutation, variables: variables, current_user: user)

      expect(graphql_data(result, "optimizeRoutes", "errors")).to be_empty
      expect(graphql_data(result, "optimizeRoutes", "routes")).not_to be_empty
    end

    it "creates an optimization job" do
      variables = {
        accountId: account.id.to_s,
        date: today.iso8601
      }

      result = execute_graphql(mutation, variables: variables, current_user: user)

      job = graphql_data(result, "optimizeRoutes", "optimizationJob")
      expect(job).to be_present
      expect(job["status"]).to eq("completed")
    end

    it "returns estimated savings" do
      variables = {
        accountId: account.id.to_s,
        date: today.iso8601
      }

      result = execute_graphql(mutation, variables: variables, current_user: user)

      savings = graphql_data(result, "optimizeRoutes", "estimatedSavings")
      expect(savings).to be_present
    end

    it "sets routes to optimized status" do
      variables = {
        accountId: account.id.to_s,
        date: today.iso8601
      }

      result = execute_graphql(mutation, variables: variables, current_user: user)

      routes = graphql_data(result, "optimizeRoutes", "routes")
      routes.each do |route|
        expect(route["status"]).to eq("optimized")
      end
    end
  end

  describe "optimization types" do
    let(:vertical) { create(:vertical, :cleaning) }
    let(:account) { create(:account, vertical: vertical) }
    let(:service_type) { create(:service_type, vertical: vertical) }
    let(:staff) { create(:staff, account: account) }
    let(:user) { create(:user, account: account) }
    let(:today) { Date.current }

    before do
      customer = create(:customer, account: account)
      create(:appointment,
        account: account,
        customer: customer,
        service_type: service_type,
        staff: staff,
        scheduled_at: today.to_time + 9.hours,
        status: "scheduled"
      )
    end

    %w[minimize_travel_time minimize_total_cost balance_workload maximize_revenue].each do |opt_type|
      it "accepts #{opt_type} optimization type" do
        variables = {
          accountId: account.id.to_s,
          date: today.iso8601,
          optimizationType: opt_type
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        expect(graphql_data(result, "optimizeRoutes", "errors")).to be_empty
      end
    end

    it "rejects invalid optimization type" do
      variables = {
        accountId: account.id.to_s,
        date: today.iso8601,
        optimizationType: "invalid_type"
      }

      result = execute_graphql(mutation, variables: variables, current_user: user)

      errors = graphql_data(result, "optimizeRoutes", "errors")
      expect(errors.first).to include("Invalid optimization type")
    end
  end

  describe "caching behavior" do
    let(:vertical) { create(:vertical, :cleaning) }
    let(:account) { create(:account, vertical: vertical) }
    let(:service_type) { create(:service_type, vertical: vertical) }
    let(:staff) { create(:staff, account: account) }
    let(:user) { create(:user, account: account) }
    let(:today) { Date.current }

    before do
      customer = create(:customer, account: account)
      create(:appointment,
        account: account,
        customer: customer,
        service_type: service_type,
        staff: staff,
        scheduled_at: today.to_time + 9.hours,
        status: "scheduled"
      )
    end

    it "returns cached result when optimization already exists" do
      variables = {
        accountId: account.id.to_s,
        date: today.iso8601
      }

      first_result = execute_graphql(mutation, variables: variables, current_user: user)
      first_job_id = graphql_data(first_result, "optimizeRoutes", "optimizationJob", "id")

      second_result = execute_graphql(mutation, variables: variables, current_user: user)
      second_job_id = graphql_data(second_result, "optimizeRoutes", "optimizationJob", "id")

      expect(second_job_id).to eq(first_job_id)
    end

    it "forces reoptimization when flag is set" do
      variables = {
        accountId: account.id.to_s,
        date: today.iso8601
      }

      first_result = execute_graphql(mutation, variables: variables, current_user: user)
      first_job_id = graphql_data(first_result, "optimizeRoutes", "optimizationJob", "id")

      variables_with_force = variables.merge(forceReoptimization: true)
      second_result = execute_graphql(mutation, variables: variables_with_force, current_user: user)
      second_job_id = graphql_data(second_result, "optimizeRoutes", "optimizationJob", "id")

      expect(second_job_id).not_to eq(first_job_id)
    end
  end

  describe "filtering by staff" do
    let(:vertical) { create(:vertical, :cleaning) }
    let(:account) { create(:account, vertical: vertical) }
    let(:service_type) { create(:service_type, vertical: vertical, duration_minutes: 60) }
    let(:staff1) { create(:staff, :downtown_based, account: account) }
    let(:staff2) { create(:staff, :west_based, account: account) }
    let(:user) { create(:user, account: account) }
    let(:today) { Date.current }

    before do
      customer1 = create(:customer, :downtown, account: account)
      customer2 = create(:customer, :west_edmonton, account: account)

      create(:appointment,
        account: account,
        customer: customer1,
        service_type: service_type,
        staff: staff1,
        scheduled_at: today.to_time + 9.hours,
        status: "scheduled"
      )

      create(:appointment,
        account: account,
        customer: customer2,
        service_type: service_type,
        staff: staff2,
        scheduled_at: today.to_time + 10.hours,
        status: "scheduled"
      )
    end

    it "optimizes only for specified staff" do
      variables = {
        accountId: account.id.to_s,
        date: today.iso8601,
        staffIds: [staff1.id.to_s],
        forceReoptimization: true
      }

      result = execute_graphql(mutation, variables: variables, current_user: user)

      errors = graphql_data(result, "optimizeRoutes", "errors")
      expect(errors).to be_empty

      routes = graphql_data(result, "optimizeRoutes", "routes")
      expect(routes.count).to eq(1)
    end
  end

  describe "authorization" do
    let(:vertical) { create(:vertical, :cleaning) }
    let(:account) { create(:account, vertical: vertical) }
    let(:other_account) { create(:account, vertical: vertical) }
    let(:today) { Date.current }

    context "when user is not logged in" do
      it "returns authentication error" do
        variables = {
          accountId: account.id.to_s,
          date: today.iso8601
        }

        result = execute_graphql(mutation, variables: variables)

        expect(graphql_errors(result)).to include("You must be logged in to perform this action")
      end
    end

    context "when user tries to access another account" do
      let(:user) { create(:user, account: other_account) }

      it "returns authorization error" do
        variables = {
          accountId: account.id.to_s,
          date: today.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        expect(graphql_errors(result)).to include("You do not have access to this account")
      end
    end
  end

  describe "error handling" do
    context "no appointments" do
      let(:account) { create(:account) }
      let(:user) { create(:user, account: account) }
      let(:today) { Date.current }

      it "returns error when no appointments exist" do
        variables = {
          accountId: account.id.to_s,
          date: today.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        errors = graphql_data(result, "optimizeRoutes", "errors")
        expect(errors.first).to include("No appointments found")
      end
    end

    context "invalid account" do
      let(:user) { create(:user, account: nil, role: "admin") }

      it "returns error for non-existent account" do
        variables = {
          accountId: "99999",
          date: Date.current.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        expect(graphql_errors(result)).to include("You do not have access to this account")
      end
    end
  end
end
