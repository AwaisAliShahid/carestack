# frozen_string_literal: true

require "rails_helper"

RSpec.describe RouteStop, type: :model do
  describe "validations" do
    let(:route) { create(:route) }
    let(:appointment) { create(:appointment, account: route.account) }

    subject { build(:route_stop, route: route, appointment: appointment) }

    it { is_expected.to be_valid }

    describe "stop_order" do
      it "is required" do
        subject.stop_order = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:stop_order]).to include("can't be blank")
      end

      it "must be unique within a route" do
        create(:route_stop, route: route, appointment: appointment, stop_order: 0)
        other_appointment = create(:appointment, account: route.account)
        subject.appointment = other_appointment
        subject.stop_order = 0

        expect(subject).not_to be_valid
        expect(subject.errors[:stop_order]).to include("has already been taken")
      end

      it "allows same stop_order on different routes" do
        other_route = create(:route, account: route.account)
        create(:route_stop, route: route, appointment: appointment, stop_order: 0)

        other_appointment = create(:appointment, account: route.account)
        other_stop = build(:route_stop, route: other_route, appointment: other_appointment, stop_order: 0)

        expect(other_stop).to be_valid
      end
    end

    describe "estimated_arrival" do
      it "is required" do
        subject.estimated_arrival = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:estimated_arrival]).to include("can't be blank")
      end
    end
  end

  describe "associations" do
    let(:route_stop) { create(:route_stop) }

    it "belongs to a route" do
      expect(route_stop.route).to be_a(Route)
    end

    it "belongs to an appointment" do
      expect(route_stop.appointment).to be_a(Appointment)
    end
  end

  describe "scopes" do
    describe ".ordered" do
      it "returns stops ordered by stop_order" do
        route = create(:route)
        account = route.account

        apt1 = create(:appointment, account: account)
        apt2 = create(:appointment, account: account)
        apt3 = create(:appointment, account: account)

        stop2 = create(:route_stop, route: route, appointment: apt2, stop_order: 1)
        stop1 = create(:route_stop, route: route, appointment: apt1, stop_order: 0)
        stop3 = create(:route_stop, route: route, appointment: apt3, stop_order: 2)

        expect(route.route_stops.ordered).to eq([ stop1, stop2, stop3 ])
      end
    end
  end

  describe "instance methods" do
    describe "#duration_at_stop" do
      it "calculates duration between arrival and departure" do
        arrival = Time.current
        departure = arrival + 2.hours

        route_stop = build(:route_stop, estimated_arrival: arrival, estimated_departure: departure)
        expect(route_stop.duration_at_stop).to eq(2.hours)
      end

      it "returns 0 when departure is blank" do
        route_stop = build(:route_stop, estimated_arrival: Time.current, estimated_departure: nil)
        expect(route_stop.duration_at_stop).to eq(0)
      end

      it "returns 0 when arrival is blank" do
        route_stop = build(:route_stop, estimated_arrival: nil, estimated_departure: Time.current)
        expect(route_stop.duration_at_stop).to eq(0)
      end
    end

    describe "#service_duration" do
      it "returns the service type duration in seconds" do
        service_type = create(:service_type, duration_minutes: 120)
        appointment = create(:appointment, service_type: service_type)
        route_stop = create(:route_stop, appointment: appointment)

        expect(route_stop.service_duration).to eq(7200) # 120 minutes * 60 seconds
      end
    end

    describe "#buffer_time" do
      it "calculates buffer time at stop" do
        service_type = create(:service_type, duration_minutes: 60)
        appointment = create(:appointment, service_type: service_type)

        arrival = Time.current
        departure = arrival + 75.minutes # 60 min service + 15 min buffer

        route_stop = create(:route_stop, appointment: appointment, estimated_arrival: arrival, estimated_departure: departure)
        expect(route_stop.buffer_time).to eq(15.minutes)
      end
    end

    describe "#on_time?" do
      let(:route_stop) do
        create(:route_stop, estimated_arrival: Time.current)
      end

      it "returns nil when actual_arrival is blank" do
        expect(route_stop.on_time?).to be_nil
      end

      it "returns true when arrival is within 15 minutes" do
        route_stop.update!(actual_arrival: route_stop.estimated_arrival + 10.minutes)
        expect(route_stop.on_time?).to be true
      end

      it "returns true when arrival is exactly on time" do
        route_stop.update!(actual_arrival: route_stop.estimated_arrival)
        expect(route_stop.on_time?).to be true
      end

      it "returns false when arrival is more than 15 minutes late" do
        route_stop.update!(actual_arrival: route_stop.estimated_arrival + 20.minutes)
        expect(route_stop.on_time?).to be false
      end
    end

    describe "#delayed?" do
      let(:route_stop) do
        create(:route_stop, estimated_arrival: Time.current)
      end

      it "returns false when actual_arrival is blank" do
        expect(route_stop.delayed?).to be false
      end

      it "returns false when arrival is within 15 minutes" do
        route_stop.update!(actual_arrival: route_stop.estimated_arrival + 10.minutes)
        expect(route_stop.delayed?).to be false
      end

      it "returns true when arrival is more than 15 minutes late" do
        route_stop.update!(actual_arrival: route_stop.estimated_arrival + 20.minutes)
        expect(route_stop.delayed?).to be true
      end

      it "returns false when arrival is early" do
        route_stop.update!(actual_arrival: route_stop.estimated_arrival - 10.minutes)
        expect(route_stop.delayed?).to be false
      end
    end

    describe "#delay_minutes" do
      let(:route_stop) do
        create(:route_stop, estimated_arrival: Time.current)
      end

      it "returns 0 when actual_arrival is blank" do
        expect(route_stop.delay_minutes).to eq(0)
      end

      it "returns positive minutes when late" do
        route_stop.update!(actual_arrival: route_stop.estimated_arrival + 30.minutes)
        expect(route_stop.delay_minutes).to eq(30)
      end

      it "returns 0 when early" do
        route_stop.update!(actual_arrival: route_stop.estimated_arrival - 10.minutes)
        expect(route_stop.delay_minutes).to eq(0)
      end

      it "returns 0 when on time" do
        route_stop.update!(actual_arrival: route_stop.estimated_arrival)
        expect(route_stop.delay_minutes).to eq(0)
      end
    end
  end

  describe "factory traits" do
    it "creates on-time stop" do
      route_stop = create(:route_stop, :on_time)
      expect(route_stop.on_time?).to be true
    end

    it "creates early arrival stop" do
      route_stop = create(:route_stop, :arrived_early)
      expect(route_stop.actual_arrival).to be < route_stop.estimated_arrival
    end

    it "creates late arrival stop" do
      route_stop = create(:route_stop, :arrived_late)
      expect(route_stop.delayed?).to be true
    end

    it "creates significantly delayed stop" do
      route_stop = create(:route_stop, :significantly_delayed)
      expect(route_stop.delay_minutes).to be >= 60
    end
  end
end
