# frozen_string_literal: true

require "rails_helper"

RSpec.describe MockGoogleMapsService do
  subject(:service) { described_class.new }

  describe "#geocode" do
    context "with known location names" do
      it "returns downtown Edmonton coordinates" do
        result = service.geocode("downtown")

        expect(result[:lat]).to eq(53.5461)
        expect(result[:lng]).to eq(-113.4938)
        expect(result[:formatted_address]).to include("Downtown Edmonton")
      end

      it "returns west Edmonton coordinates" do
        result = service.geocode("west")

        expect(result[:lat]).to eq(53.5232)
        expect(result[:lng]).to eq(-113.5263)
        expect(result[:formatted_address]).to include("West Edmonton")
      end

      it "returns north Edmonton coordinates" do
        result = service.geocode("north")

        expect(result[:lat]).to eq(53.5731)
        expect(result[:lng]).to eq(-113.4903)
        expect(result[:formatted_address]).to include("North Edmonton")
      end

      it "returns south Edmonton coordinates" do
        result = service.geocode("south")

        expect(result[:lat]).to eq(53.4668)
        expect(result[:lng]).to eq(-113.5114)
        expect(result[:formatted_address]).to include("South Edmonton")
      end

      it "returns east Edmonton coordinates" do
        result = service.geocode("east")

        expect(result[:lat]).to eq(53.5586)
        expect(result[:lng]).to eq(-113.4086)
        expect(result[:formatted_address]).to include("East Edmonton")
      end
    end

    context "with unknown location" do
      it "returns Edmonton area coordinates and formatted address" do
        result = service.geocode("Unknown Street 123")

        # Just verify it returns reasonable Edmonton-area coordinates
        expect(result[:lat]).to be_a(Numeric)
        expect(result[:lng]).to be_a(Numeric)
        expect(result[:formatted_address]).to include("Edmonton, AB, Canada")
      end
    end

    context "case insensitivity" do
      it "handles uppercase input" do
        result = service.geocode("DOWNTOWN")

        expect(result[:lat]).to eq(53.5461)
        expect(result[:lng]).to eq(-113.4938)
      end

      it "handles mixed case input" do
        result = service.geocode("DoWnToWn")

        expect(result[:lat]).to eq(53.5461)
        expect(result[:lng]).to eq(-113.4938)
      end
    end
  end

  describe "#distance_matrix" do
    let(:locations) do
      [
        { id: 1, lat: 53.5461, lng: -113.4938 }, # Downtown
        { id: 2, lat: 53.5232, lng: -113.5263 }, # West
        { id: 3, lat: 53.4668, lng: -113.5114 }  # South
      ]
    end

    it "returns distance data for all location pairs" do
      result = service.distance_matrix(locations)

      # Should have entries for all non-same pairs (n * (n-1) = 3 * 2 = 6)
      expect(result.keys.count).to eq(6)
    end

    it "returns distance and duration for each pair" do
      result = service.distance_matrix(locations)

      key = "1:2"
      expect(result[key]).to include(:distance_meters, :duration_seconds)
      expect(result[key][:distance_meters]).to be > 0
      expect(result[key][:duration_seconds]).to be > 0
    end

    it "includes traffic duration" do
      result = service.distance_matrix(locations)

      key = "1:2"
      expect(result[key]).to include(:duration_in_traffic_seconds)
      expect(result[key][:duration_in_traffic_seconds]).to be >= result[key][:duration_seconds]
    end

    it "does not include same-location pairs" do
      result = service.distance_matrix(locations)

      expect(result).not_to have_key("1:1")
      expect(result).not_to have_key("2:2")
      expect(result).not_to have_key("3:3")
    end

    it "uses Haversine formula for realistic distances" do
      result = service.distance_matrix(locations)

      # Distance from downtown to west Edmonton should be roughly 2-5 km
      downtown_to_west = result["1:2"][:distance_meters]
      expect(downtown_to_west).to be_between(2000, 10_000)
    end

    it "estimates travel time based on 40 km/h average speed" do
      result = service.distance_matrix(locations)

      key = "1:2"
      distance_km = result[key][:distance_meters] / 1000.0
      duration_hours = result[key][:duration_seconds] / 3600.0

      # Speed should be around 40 km/h
      calculated_speed = distance_km / duration_hours
      expect(calculated_speed).to be_within(1).of(40)
    end

    it "preserves location references" do
      result = service.distance_matrix(locations)

      key = "1:2"
      expect(result[key][:from_location][:id]).to eq(1)
      expect(result[key][:to_location][:id]).to eq(2)
    end
  end

  describe "Haversine distance calculation" do
    it "calculates correct distance between known points" do
      # Downtown to West Edmonton is approximately 3.5 km
      downtown = [ 53.5461, -113.4938 ]
      west = [ 53.5232, -113.5263 ]

      locations = [
        { id: 1, lat: downtown[0], lng: downtown[1] },
        { id: 2, lat: west[0], lng: west[1] }
      ]

      result = service.distance_matrix(locations)
      distance_km = result["1:2"][:distance_meters] / 1000.0

      # Should be between 3-5 km based on actual Edmonton geography
      expect(distance_km).to be_between(2.5, 5.0)
    end

    it "returns zero-ish distance for same coordinates" do
      locations = [
        { id: 1, lat: 53.5461, lng: -113.4938 },
        { id: 2, lat: 53.5461, lng: -113.4938 } # Same location, different ID
      ]

      result = service.distance_matrix(locations)

      # Very small distance (essentially 0)
      expect(result["1:2"][:distance_meters]).to be < 1
    end

    it "handles locations across larger distances" do
      # Edmonton to Calgary is ~300 km
      edmonton = { id: 1, lat: 53.5461, lng: -113.4938 }
      calgary = { id: 2, lat: 51.0447, lng: -114.0719 }

      result = service.distance_matrix([ edmonton, calgary ])
      distance_km = result["1:2"][:distance_meters] / 1000.0

      # Straight-line distance should be around 270-280 km
      expect(distance_km).to be_between(250, 300)
    end
  end
end
