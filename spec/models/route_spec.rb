# frozen_string_literal: true

require "rails_helper"

RSpec.describe Route, type: :model do
  describe "validations" do
    subject { build(:route) }

    it { is_expected.to be_valid }

    describe "scheduled_date" do
      it "is required" do
        subject.scheduled_date = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:scheduled_date]).to include("can't be blank")
      end
    end

    describe "status" do
      it "is required" do
        subject.status = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:status]).to include("can't be blank")
      end

      it "must be a valid status" do
        subject.status = "invalid_status"
        expect(subject).not_to be_valid
        expect(subject.errors[:status]).to include("is not included in the list")
      end

      %w[pending optimized active completed cancelled].each do |valid_status|
        it "accepts '#{valid_status}' as valid status" do
          subject.status = valid_status
          expect(subject).to be_valid
        end
      end
    end
  end

  describe "associations" do
    let(:route) { create(:route) }

    it "belongs to an account" do
      expect(route.account).to be_a(Account)
    end

    it "has many route_stops" do
      appointment = create(:appointment, account: route.account)
      route_stop = create(:route_stop, route: route, appointment: appointment)
      expect(route.route_stops).to include(route_stop)
    end

    it "has many appointments through route_stops" do
      appointment = create(:appointment, account: route.account)
      create(:route_stop, route: route, appointment: appointment)
      expect(route.appointments).to include(appointment)
    end

    it "destroys route_stops when destroyed" do
      appointment = create(:appointment, account: route.account)
      create(:route_stop, route: route, appointment: appointment)
      expect { route.destroy }.to change(RouteStop, :count).by(-1)
    end
  end

  describe "scopes" do
    describe ".for_date" do
      it "returns routes for the specified date" do
        today_route = create(:route, :today)
        create(:route, :tomorrow)

        expect(Route.for_date(Date.current)).to eq([ today_route ])
      end
    end

    describe ".active" do
      it "returns only optimized and active routes" do
        optimized = create(:route, :optimized)
        active = create(:route, :active)
        create(:route, :pending)
        create(:route, :completed)
        create(:route, :cancelled)

        expect(Route.active).to contain_exactly(optimized, active)
      end
    end
  end

  describe "instance methods" do
    describe "#total_distance_km" do
      it "converts meters to kilometers" do
        route = build(:route, total_distance_meters: 15_000)
        expect(route.total_distance_km).to eq(15.0)
      end

      it "handles zero distance" do
        route = build(:route, total_distance_meters: 0)
        expect(route.total_distance_km).to eq(0.0)
      end

      it "handles fractional kilometers" do
        route = build(:route, total_distance_meters: 7_500)
        expect(route.total_distance_km).to eq(7.5)
      end
    end

    describe "#total_duration_hours" do
      it "converts seconds to hours" do
        route = build(:route, total_duration_seconds: 7200)
        expect(route.total_duration_hours).to eq(2.0)
      end

      it "handles fractional hours" do
        route = build(:route, total_duration_seconds: 5400) # 1.5 hours
        expect(route.total_duration_hours).to eq(1.5)
      end

      it "handles zero duration" do
        route = build(:route, total_duration_seconds: 0)
        expect(route.total_duration_hours).to eq(0.0)
      end
    end

    describe "#estimated_fuel_cost" do
      it "calculates fuel cost with default rate" do
        route = build(:route, total_distance_meters: 100_000) # 100 km
        expect(route.estimated_fuel_cost).to eq(15.0) # 100 km * $0.15
      end

      it "calculates fuel cost with custom rate" do
        route = build(:route, total_distance_meters: 100_000)
        expect(route.estimated_fuel_cost(0.20)).to eq(20.0)
      end

      it "handles short routes" do
        route = build(:route, total_distance_meters: 5_000) # 5 km
        expect(route.estimated_fuel_cost).to eq(0.75)
      end
    end

    describe "#staff_member" do
      it "returns the staff member from the first route stop" do
        account = create(:account)
        route = create(:route, account: account)
        staff = create(:staff, account: account)
        appointment = create(:appointment, account: account, staff: staff)
        create(:route_stop, route: route, appointment: appointment, stop_order: 0)

        expect(route.staff_member).to eq(staff)
      end

      it "returns nil when no route stops exist" do
        route = create(:route)
        expect(route.staff_member).to be_nil
      end
    end
  end

  describe "factory traits" do
    it "creates pending route" do
      route = create(:route, :pending)
      expect(route.status).to eq("pending")
    end

    it "creates optimized route" do
      route = create(:route, :optimized)
      expect(route.status).to eq("optimized")
    end

    it "creates short route with reduced distance and duration" do
      route = create(:route, :short_route)
      expect(route.total_distance_meters).to eq(5_000)
      expect(route.total_duration_seconds).to eq(1800)
    end

    it "creates long route with increased distance and duration" do
      route = create(:route, :long_route)
      expect(route.total_distance_meters).to eq(50_000)
      expect(route.total_duration_seconds).to eq(7200)
    end

    it "creates route with stops" do
      route = create(:route, :with_stops, stop_count: 4)
      expect(route.route_stops.count).to eq(4)
    end
  end
end
