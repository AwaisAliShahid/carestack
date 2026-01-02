# frozen_string_literal: true

require "rails_helper"

RSpec.describe TravelSegment, type: :model do
  describe "validations" do
    subject { build(:travel_segment) }

    it { is_expected.to be_valid }

    describe "distance_meters" do
      it "is required" do
        subject.distance_meters = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:distance_meters]).to include("can't be blank")
      end

      it "must be greater than 0" do
        subject.distance_meters = 0
        expect(subject).not_to be_valid
        expect(subject.errors[:distance_meters]).to include("must be greater than 0")
      end

      it "accepts positive values" do
        subject.distance_meters = 5000
        expect(subject).to be_valid
      end
    end

    describe "duration_seconds" do
      it "is required" do
        subject.duration_seconds = nil
        expect(subject).not_to be_valid
        expect(subject.errors[:duration_seconds]).to include("can't be blank")
      end

      it "must be greater than 0" do
        subject.duration_seconds = 0
        expect(subject).not_to be_valid
        expect(subject.errors[:duration_seconds]).to include("must be greater than 0")
      end

      it "accepts positive values" do
        subject.duration_seconds = 600
        expect(subject).to be_valid
      end
    end

    describe "traffic_factor" do
      it "allows nil values" do
        subject.traffic_factor = nil
        expect(subject).to be_valid
      end

      it "must be greater than 0 when present" do
        subject.traffic_factor = 0
        expect(subject).not_to be_valid
        expect(subject.errors[:traffic_factor]).to include("must be greater than 0")
      end

      it "accepts positive values" do
        subject.traffic_factor = 1.5
        expect(subject).to be_valid
      end
    end
  end

  describe "associations" do
    let(:travel_segment) { create(:travel_segment) }

    it "belongs to a from_appointment" do
      expect(travel_segment.from_appointment).to be_a(Appointment)
    end

    it "belongs to a to_appointment" do
      expect(travel_segment.to_appointment).to be_a(Appointment)
    end
  end

  describe "instance methods" do
    describe "#distance_km" do
      it "converts meters to kilometers" do
        segment = build(:travel_segment, distance_meters: 5000)
        expect(segment.distance_km).to eq(5.0)
      end

      it "handles fractional kilometers" do
        segment = build(:travel_segment, distance_meters: 7500)
        expect(segment.distance_km).to eq(7.5)
      end

      it "handles small distances" do
        segment = build(:travel_segment, distance_meters: 500)
        expect(segment.distance_km).to eq(0.5)
      end
    end

    describe "#duration_minutes" do
      it "converts seconds to minutes" do
        segment = build(:travel_segment, duration_seconds: 600)
        expect(segment.duration_minutes).to eq(10.0)
      end

      it "handles fractional minutes" do
        segment = build(:travel_segment, duration_seconds: 90)
        expect(segment.duration_minutes).to eq(1.5)
      end

      it "handles large durations" do
        segment = build(:travel_segment, duration_seconds: 3600)
        expect(segment.duration_minutes).to eq(60.0)
      end
    end

    describe "#duration_with_traffic" do
      it "returns duration adjusted by traffic factor" do
        segment = build(:travel_segment, duration_seconds: 600, traffic_factor: 1.5)
        expect(segment.duration_with_traffic).to eq(900)
      end

      it "returns original duration when traffic_factor is nil" do
        segment = build(:travel_segment, duration_seconds: 600, traffic_factor: nil)
        expect(segment.duration_with_traffic).to eq(600)
      end

      it "handles traffic factor less than 1 (light traffic)" do
        segment = build(:travel_segment, duration_seconds: 600, traffic_factor: 0.8)
        expect(segment.duration_with_traffic).to eq(480)
      end

      it "returns integer value" do
        segment = build(:travel_segment, duration_seconds: 100, traffic_factor: 1.33)
        expect(segment.duration_with_traffic).to be_a(Integer)
      end
    end
  end

  describe "factory traits" do
    it "creates short distance segment" do
      segment = create(:travel_segment, :short_distance)
      expect(segment.distance_meters).to eq(1000)
      expect(segment.duration_seconds).to eq(180)
    end

    it "creates long distance segment" do
      segment = create(:travel_segment, :long_distance)
      expect(segment.distance_meters).to eq(25_000)
      expect(segment.duration_seconds).to eq(1800)
    end

    it "creates heavy traffic segment" do
      segment = create(:travel_segment, :heavy_traffic)
      expect(segment.traffic_factor).to eq(1.5)
    end

    it "creates light traffic segment" do
      segment = create(:travel_segment, :light_traffic)
      expect(segment.traffic_factor).to eq(0.9)
    end

    it "creates segment without traffic data" do
      segment = create(:travel_segment, :no_traffic_data)
      expect(segment.traffic_factor).to be_nil
    end
  end

  describe "data integrity" do
    it "represents a valid travel path between appointments" do
      account = create(:account)
      from_apt = create(:appointment, account: account)
      to_apt = create(:appointment, account: account)

      segment = create(:travel_segment, from_appointment: from_apt, to_appointment: to_apt)

      expect(segment.from_appointment).to eq(from_apt)
      expect(segment.to_appointment).to eq(to_apt)
    end
  end
end
