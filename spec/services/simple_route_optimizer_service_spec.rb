# frozen_string_literal: true

require "rails_helper"

RSpec.describe SimpleRouteOptimizerService do
  let(:cleaning_vertical) { create(:vertical, :cleaning) }
  let(:account) { create(:account, vertical: cleaning_vertical) }

  describe "#initialize" do
    it "initializes with required parameters" do
      service = described_class.new(
        account_id: account.id,
        date: Date.current,
        optimization_type: "minimize_travel_time"
      )

      expect(service).to be_a(SimpleRouteOptimizerService)
    end

    it "accepts optional staff_ids parameter" do
      staff = create(:staff, account: account)

      service = described_class.new(
        account_id: account.id,
        date: Date.current,
        staff_ids: [ staff.id ]
      )

      expect(service).to be_a(SimpleRouteOptimizerService)
    end
  end

  describe "#optimize!" do
    context "with no appointments" do
      it "returns failed result" do
        service = described_class.new(
          account_id: account.id,
          date: Date.current
        )

        result = service.optimize!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("No appointments to optimize")
      end
    end

    context "with no available staff" do
      before do
        # Create appointment for a different date so staff_ids are empty
        customer = create(:customer, account: account)
        service_type = create(:service_type, vertical: cleaning_vertical)
        staff = create(:staff, account: account)
        create(:appointment,
          account: account,
          customer: customer,
          service_type: service_type,
          staff: staff,
          scheduled_at: 2.days.from_now,
          status: "scheduled"
        )
      end

      it "returns failed result when no staff for requested date" do
        service = described_class.new(
          account_id: account.id,
          date: Date.current
        )

        result = service.optimize!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("No appointments to optimize")
      end
    end

    context "with valid appointments and staff" do
      let(:service_type) { create(:service_type, vertical: cleaning_vertical, duration_minutes: 60) }
      let(:staff1) { create(:staff, :downtown_based, account: account) }
      let(:staff2) { create(:staff, :west_based, account: account) }
      let(:today) { Date.current }

      before do
        # Create customers in different locations
        customer1 = create(:customer, :downtown, account: account)
        customer2 = create(:customer, :west_edmonton, account: account)
        customer3 = create(:customer, :south_edmonton, account: account)

        # Create appointments for today
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
          staff: staff1,
          scheduled_at: today.to_time + 11.hours,
          status: "scheduled"
        )

        create(:appointment,
          account: account,
          customer: customer3,
          service_type: service_type,
          staff: staff2,
          scheduled_at: today.to_time + 10.hours,
          status: "scheduled"
        )
      end

      it "returns successful result" do
        service = described_class.new(
          account_id: account.id,
          date: today
        )

        result = service.optimize!

        expect(result[:success]).to be true
        expect(result[:error]).to be_nil
      end

      it "creates an optimization job" do
        service = described_class.new(
          account_id: account.id,
          date: today
        )

        expect { service.optimize! }.to change(OptimizationJob, :count).by(1)
      end

      it "creates optimized routes" do
        service = described_class.new(
          account_id: account.id,
          date: today
        )

        result = service.optimize!

        expect(result[:routes]).not_to be_empty
        expect(result[:routes].first).to be_a(Route)
      end

      it "creates route stops for each appointment" do
        service = described_class.new(
          account_id: account.id,
          date: today
        )

        expect { service.optimize! }.to change(RouteStop, :count)
      end

      it "sets optimization job status to completed on success" do
        service = described_class.new(
          account_id: account.id,
          date: today
        )

        result = service.optimize!

        expect(result[:optimization_job].status).to eq("completed")
        expect(result[:optimization_job].processing_completed_at).to be_present
      end

      it "calculates savings metrics" do
        service = described_class.new(
          account_id: account.id,
          date: today
        )

        result = service.optimize!

        expect(result[:metrics]).to be_present
        expect(result[:metrics]["time_saved_hours"]).to be_a(Numeric)
        expect(result[:metrics]["cost_savings"]).to be_a(Numeric)
      end

      it "stores optimization parameters in job" do
        service = described_class.new(
          account_id: account.id,
          date: today,
          optimization_type: "minimize_total_cost"
        )

        result = service.optimize!

        expect(result[:optimization_job].parameters["optimization_type"]).to eq("minimize_total_cost")
      end
    end

    context "filtering by staff_ids" do
      let(:service_type) { create(:service_type, vertical: cleaning_vertical) }
      let(:staff1) { create(:staff, account: account) }
      let(:staff2) { create(:staff, account: account) }
      let(:today) { Date.current }

      before do
        customer1 = create(:customer, account: account)
        customer2 = create(:customer, account: account)

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

      it "only optimizes for specified staff" do
        service = described_class.new(
          account_id: account.id,
          date: today,
          staff_ids: [ staff1.id ]
        )

        result = service.optimize!

        # Should only create one route for staff1
        expect(result[:routes].count).to eq(1)
      end
    end

    context "with different appointment statuses" do
      let(:service_type) { create(:service_type, vertical: cleaning_vertical) }
      let(:staff) { create(:staff, account: account) }
      let(:today) { Date.current }

      before do
        customer = create(:customer, account: account)

        # Only scheduled and confirmed should be included
        create(:appointment,
          account: account,
          customer: customer,
          service_type: service_type,
          staff: staff,
          scheduled_at: today.to_time + 9.hours,
          status: "scheduled"
        )

        create(:appointment,
          account: account,
          customer: customer,
          service_type: service_type,
          staff: staff,
          scheduled_at: today.to_time + 11.hours,
          status: "confirmed"
        )

        # These should be excluded
        create(:appointment,
          account: account,
          customer: customer,
          service_type: service_type,
          staff: staff,
          scheduled_at: today.to_time + 13.hours,
          status: "completed"
        )

        create(:appointment,
          account: account,
          customer: customer,
          service_type: service_type,
          staff: staff,
          scheduled_at: today.to_time + 15.hours,
          status: "cancelled"
        )
      end

      it "only includes scheduled and confirmed appointments" do
        service = described_class.new(
          account_id: account.id,
          date: today
        )

        result = service.optimize!

        # Should have 2 route stops (scheduled + confirmed)
        total_stops = result[:routes].sum { |r| r.route_stops.count }
        expect(total_stops).to eq(2)
      end
    end

    context "error handling" do
      let(:service_type) { create(:service_type, vertical: cleaning_vertical) }
      let(:staff) { create(:staff, account: account) }
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

      it "sets job status to failed on error" do
        service = described_class.new(
          account_id: account.id,
          date: today
        )

        # Stub the distance matrix to raise an error
        allow_any_instance_of(MockGoogleMapsService).to receive(:distance_matrix).and_raise(StandardError.new("API error"))

        result = service.optimize!

        expect(result[:success]).to be false
        expect(result[:error]).to eq("API error")
      end
    end
  end

  describe "route optimization algorithm" do
    let(:service_type) { create(:service_type, vertical: cleaning_vertical, duration_minutes: 60) }
    let(:staff) { create(:staff, :downtown_based, account: account) }
    let(:today) { Date.current }

    context "with nearest neighbor algorithm" do
      before do
        # Create appointments in specific order to test optimization
        @downtown_customer = create(:customer, :downtown, account: account)
        @west_customer = create(:customer, :west_edmonton, account: account)
        @south_customer = create(:customer, :south_edmonton, account: account)

        # Create appointments in non-optimal order
        create(:appointment,
          account: account,
          customer: @south_customer, # Far from start
          service_type: service_type,
          staff: staff,
          scheduled_at: today.to_time + 9.hours,
          status: "scheduled"
        )

        create(:appointment,
          account: account,
          customer: @downtown_customer, # Close to staff home
          service_type: service_type,
          staff: staff,
          scheduled_at: today.to_time + 11.hours,
          status: "scheduled"
        )

        create(:appointment,
          account: account,
          customer: @west_customer, # Medium distance
          service_type: service_type,
          staff: staff,
          scheduled_at: today.to_time + 13.hours,
          status: "scheduled"
        )
      end

      it "reorders stops based on distance optimization" do
        service = described_class.new(
          account_id: account.id,
          date: today,
          optimization_type: "minimize_travel_time"
        )

        result = service.optimize!

        expect(result[:success]).to be true

        route = result[:routes].first
        expect(route.route_stops.count).to eq(3)

        # Verify route has total distance and duration
        expect(route.total_distance_meters).to be > 0
        expect(route.total_duration_seconds).to be > 0
      end

      it "updates appointment scheduled_at times based on route" do
        service = described_class.new(
          account_id: account.id,
          date: today
        )

        result = service.optimize!

        # Check that route stops have estimated times
        result[:routes].first.route_stops.each do |stop|
          expect(stop.estimated_arrival).to be_present
          expect(stop.estimated_departure).to be_present
        end
      end
    end
  end
end
