# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::CreateAppointment, type: :graphql do
  let(:mutation) do
    <<~GQL
      mutation CreateAppointment(
        $accountId: ID!
        $customerId: ID!
        $serviceTypeId: ID!
        $staffId: ID!
        $scheduledAt: ISO8601DateTime!
        $notes: String
      ) {
        createAppointment(
          accountId: $accountId
          customerId: $customerId
          serviceTypeId: $serviceTypeId
          staffId: $staffId
          scheduledAt: $scheduledAt
          notes: $notes
        ) {
          appointment {
            id
            status
            scheduledAt
            durationMinutes
            notes
          }
          errors
        }
      }
    GQL
  end

  describe "successful appointment creation" do
    context "with cleaning business" do
      let(:vertical) { create(:vertical, :cleaning) }
      let(:account) { create(:account, vertical: vertical) }
      let(:customer) { create(:customer, account: account) }
      let(:service_type) { create(:service_type, vertical: vertical, duration_minutes: 120) }
      let(:staff) { create(:staff, account: account) }
      let(:user) { create(:user, account: account) }

      it "creates an appointment successfully" do
        variables = {
          accountId: account.id.to_s,
          customerId: customer.id.to_s,
          serviceTypeId: service_type.id.to_s,
          staffId: staff.id.to_s,
          scheduledAt: 1.day.from_now.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        expect(graphql_data(result, "createAppointment", "errors")).to be_empty
        expect(graphql_data(result, "createAppointment", "appointment")).to be_present
        expect(graphql_data(result, "createAppointment", "appointment", "status")).to eq("scheduled")
      end

      it "sets duration from service type" do
        variables = {
          accountId: account.id.to_s,
          customerId: customer.id.to_s,
          serviceTypeId: service_type.id.to_s,
          staffId: staff.id.to_s,
          scheduledAt: 1.day.from_now.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        expect(graphql_data(result, "createAppointment", "appointment", "durationMinutes")).to eq(120)
      end

      it "includes notes when provided" do
        variables = {
          accountId: account.id.to_s,
          customerId: customer.id.to_s,
          serviceTypeId: service_type.id.to_s,
          staffId: staff.id.to_s,
          scheduledAt: 1.day.from_now.iso8601,
          notes: "Customer prefers morning appointments"
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        expect(graphql_data(result, "createAppointment", "appointment", "notes")).to eq("Customer prefers morning appointments")
      end

      it "creates appointment in the database" do
        variables = {
          accountId: account.id.to_s,
          customerId: customer.id.to_s,
          serviceTypeId: service_type.id.to_s,
          staffId: staff.id.to_s,
          scheduledAt: 1.day.from_now.iso8601
        }

        expect { execute_graphql(mutation, variables: variables, current_user: user) }.to change(Appointment, :count).by(1)
      end
    end

    context "with elderly care business and background-checked staff" do
      let(:vertical) { create(:vertical, :elderly_care) }
      let(:account) { create(:account, vertical: vertical) }
      let(:customer) { create(:customer, account: account) }
      let(:service_type) { create(:service_type, :companion_care, vertical: vertical) }
      let(:staff) { create(:staff, :background_checked, account: account) }
      let(:user) { create(:user, account: account) }

      it "creates appointment when staff has background check" do
        variables = {
          accountId: account.id.to_s,
          customerId: customer.id.to_s,
          serviceTypeId: service_type.id.to_s,
          staffId: staff.id.to_s,
          scheduledAt: 1.day.from_now.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        expect(graphql_data(result, "createAppointment", "errors")).to be_empty
        expect(graphql_data(result, "createAppointment", "appointment")).to be_present
      end
    end
  end

  describe "authorization" do
    let(:vertical) { create(:vertical, :cleaning) }
    let(:account) { create(:account, vertical: vertical) }
    let(:other_account) { create(:account, vertical: vertical) }
    let(:customer) { create(:customer, account: account) }
    let(:service_type) { create(:service_type, vertical: vertical) }
    let(:staff) { create(:staff, account: account) }

    context "when user is not logged in" do
      it "returns authentication error" do
        variables = {
          accountId: account.id.to_s,
          customerId: customer.id.to_s,
          serviceTypeId: service_type.id.to_s,
          staffId: staff.id.to_s,
          scheduledAt: 1.day.from_now.iso8601
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
          customerId: customer.id.to_s,
          serviceTypeId: service_type.id.to_s,
          staffId: staff.id.to_s,
          scheduledAt: 1.day.from_now.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        expect(graphql_errors(result)).to include("You do not have access to this account")
      end
    end
  end

  describe "validation errors" do
    context "vertical mismatch" do
      let(:cleaning_vertical) { create(:vertical, :cleaning) }
      let(:elderly_vertical) { create(:vertical, :elderly_care) }
      let(:account) { create(:account, vertical: cleaning_vertical) }
      let(:customer) { create(:customer, account: account) }
      let(:wrong_service_type) { create(:service_type, vertical: elderly_vertical) }
      let(:staff) { create(:staff, account: account) }
      let(:user) { create(:user, account: account) }

      it "returns error when service type is from different vertical" do
        variables = {
          accountId: account.id.to_s,
          customerId: customer.id.to_s,
          serviceTypeId: wrong_service_type.id.to_s,
          staffId: staff.id.to_s,
          scheduledAt: 1.day.from_now.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        errors = graphql_data(result, "createAppointment", "errors")
        expect(errors).to include(match(/not available for/))
        expect(graphql_data(result, "createAppointment", "appointment")).to be_nil
      end
    end

    context "staff not belonging to account" do
      let(:vertical) { create(:vertical, :cleaning) }
      let(:account) { create(:account, vertical: vertical) }
      let(:other_account) { create(:account, vertical: vertical) }
      let(:customer) { create(:customer, account: account) }
      let(:service_type) { create(:service_type, vertical: vertical) }
      let(:wrong_staff) { create(:staff, account: other_account) }
      let(:user) { create(:user, account: account) }

      it "returns error when staff belongs to different account" do
        variables = {
          accountId: account.id.to_s,
          customerId: customer.id.to_s,
          serviceTypeId: service_type.id.to_s,
          staffId: wrong_staff.id.to_s,
          scheduledAt: 1.day.from_now.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        errors = graphql_data(result, "createAppointment", "errors")
        expect(errors).to include("Staff member does not belong to this account")
      end
    end

    context "background check requirements" do
      context "for cleaning with post-construction service" do
        let(:vertical) { create(:vertical, :cleaning) }
        let(:account) { create(:account, vertical: vertical) }
        let(:customer) { create(:customer, account: account) }
        let(:service_type) { create(:service_type, :post_construction, vertical: vertical) }
        let(:staff) { create(:staff, :not_background_checked, account: account) }
        let(:user) { create(:user, account: account) }

        it "returns error when staff lacks required background check" do
          variables = {
            accountId: account.id.to_s,
            customerId: customer.id.to_s,
            serviceTypeId: service_type.id.to_s,
            staffId: staff.id.to_s,
            scheduledAt: 1.day.from_now.iso8601
          }

          result = execute_graphql(mutation, variables: variables, current_user: user)

          errors = graphql_data(result, "createAppointment", "errors")
          expect(errors).to include(match(/must have passed background check/))
        end
      end

      context "for elderly care" do
        let(:vertical) { create(:vertical, :elderly_care) }
        let(:account) { create(:account, vertical: vertical) }
        let(:customer) { create(:customer, account: account) }
        let(:service_type) { create(:service_type, :companion_care, vertical: vertical) }
        let(:staff) { create(:staff, :not_background_checked, account: account) }
        let(:user) { create(:user, account: account) }

        it "returns error when staff lacks background check" do
          variables = {
            accountId: account.id.to_s,
            customerId: customer.id.to_s,
            serviceTypeId: service_type.id.to_s,
            staffId: staff.id.to_s,
            scheduledAt: 1.day.from_now.iso8601
          }

          result = execute_graphql(mutation, variables: variables, current_user: user)

          errors = graphql_data(result, "createAppointment", "errors")
          expect(errors).to include("All elderly care staff must have passed background checks")
        end
      end
    end

    context "multi-staff requirements" do
      let(:vertical) { create(:vertical, :elderly_care) }
      let(:account) { create(:account, vertical: vertical) }
      let(:customer) { create(:customer, account: account) }
      let(:service_type) { create(:service_type, :full_day_care, vertical: vertical) }
      let(:staff) { create(:staff, :background_checked, account: account) }
      let(:user) { create(:user, account: account) }

      it "returns error for services requiring multiple staff" do
        variables = {
          accountId: account.id.to_s,
          customerId: customer.id.to_s,
          serviceTypeId: service_type.id.to_s,
          staffId: staff.id.to_s,
          scheduledAt: 1.day.from_now.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        errors = graphql_data(result, "createAppointment", "errors")
        expect(errors).to include(match(/requires.*staff members minimum/))
      end
    end

    context "record not found" do
      let(:vertical) { create(:vertical, :cleaning) }
      let(:account) { create(:account, vertical: vertical) }
      let(:user) { create(:user, account: nil, role: "admin") }

      it "returns error for non-existent account" do
        variables = {
          accountId: "99999",
          customerId: "1",
          serviceTypeId: "1",
          staffId: "1",
          scheduledAt: 1.day.from_now.iso8601
        }

        result = execute_graphql(mutation, variables: variables, current_user: user)

        expect(graphql_errors(result)).to include("You do not have access to this account")
      end
    end
  end
end
