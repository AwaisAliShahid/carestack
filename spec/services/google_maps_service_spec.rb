# frozen_string_literal: true

require "rails_helper"

RSpec.describe GoogleMapsService do
  let(:api_key) { "test_api_key_12345" }

  describe "#initialize" do
    context "with explicit API key" do
      it "initializes successfully" do
        service = described_class.new(api_key: api_key)
        expect(service).to be_a(GoogleMapsService)
      end
    end

    context "with ENV variable" do
      it "uses GOOGLE_MAPS_API_KEY from environment" do
        allow(ENV).to receive(:fetch).with("GOOGLE_MAPS_API_KEY", nil).and_return(api_key)
        allow(Rails.application.credentials).to receive(:dig).with(:google_maps, :api_key).and_return(nil)

        service = described_class.new
        expect(service).to be_a(GoogleMapsService)
      end
    end

    context "with credentials" do
      it "uses Rails credentials when available" do
        allow(Rails.application.credentials).to receive(:dig).with(:google_maps, :api_key).and_return(api_key)

        service = described_class.new
        expect(service).to be_a(GoogleMapsService)
      end
    end

    context "without API key" do
      it "raises ArgumentError" do
        allow(Rails.application.credentials).to receive(:dig).with(:google_maps, :api_key).and_return(nil)
        allow(ENV).to receive(:fetch).with("GOOGLE_MAPS_API_KEY", nil).and_return(nil)

        expect { described_class.new }.to raise_error(ArgumentError, "Google Maps API key is required")
      end
    end
  end

  describe "#geocode" do
    subject(:service) { described_class.new(api_key: api_key) }

    let(:geocode_response) do
      {
        "status" => "OK",
        "results" => [
          {
            "geometry" => {
              "location" => { "lat" => 53.5461, "lng" => -113.4938 }
            },
            "formatted_address" => "Downtown, Edmonton, AB, Canada",
            "place_id" => "ChIJ_test123"
          }
        ]
      }
    end

    before do
      stub_request(:get, %r{maps.googleapis.com/maps/api/geocode/json})
        .to_return(status: 200, body: geocode_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns geocoded location" do
      result = service.geocode("Downtown Edmonton")

      expect(result[:lat]).to eq(53.5461)
      expect(result[:lng]).to eq(-113.4938)
      expect(result[:formatted_address]).to include("Edmonton")
      expect(result[:place_id]).to be_present
    end

    it "returns nil for blank address" do
      expect(service.geocode("")).to be_nil
      expect(service.geocode(nil)).to be_nil
    end

    context "when API returns ZERO_RESULTS" do
      before do
        stub_request(:get, %r{maps.googleapis.com/maps/api/geocode/json})
          .to_return(status: 200, body: { "status" => "ZERO_RESULTS", "results" => [] }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns nil" do
        # Clear cache first
        Rails.cache.clear
        expect(service.geocode("nonexistent place xyz123")).to be_nil
      end
    end

    context "when API returns quota exceeded" do
      before do
        stub_request(:get, %r{maps.googleapis.com/maps/api/geocode/json})
          .to_return(status: 200, body: { "status" => "OVER_QUERY_LIMIT" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "raises QuotaExceededError" do
        Rails.cache.clear
        expect { service.geocode("test address") }.to raise_error(GoogleMapsService::QuotaExceededError)
      end
    end
  end

  describe "#reverse_geocode" do
    subject(:service) { described_class.new(api_key: api_key) }

    let(:reverse_geocode_response) do
      {
        "status" => "OK",
        "results" => [
          {
            "formatted_address" => "123 Main St, Edmonton, AB T5K 0L4, Canada",
            "place_id" => "ChIJ_reverse123",
            "address_components" => [
              { "long_name" => "123", "types" => ["street_number"] },
              { "long_name" => "Main Street", "types" => ["route"] },
              { "long_name" => "Edmonton", "types" => ["locality"] },
              { "long_name" => "Alberta", "types" => ["administrative_area_level_1"] },
              { "long_name" => "Canada", "types" => ["country"] },
              { "long_name" => "T5K 0L4", "types" => ["postal_code"] }
            ]
          }
        ]
      }
    end

    before do
      stub_request(:get, %r{maps.googleapis.com/maps/api/geocode/json})
        .to_return(status: 200, body: reverse_geocode_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns address details" do
      result = service.reverse_geocode(lat: 53.5461, lng: -113.4938)

      expect(result[:formatted_address]).to include("Edmonton")
      expect(result[:place_id]).to be_present
      expect(result[:address_components][:city]).to eq("Edmonton")
      expect(result[:address_components][:province]).to eq("Alberta")
    end
  end

  describe "#distance_matrix" do
    subject(:service) { described_class.new(api_key: api_key) }

    let(:locations) do
      [
        { id: 1, lat: 53.5461, lng: -113.4938 },
        { id: 2, lat: 53.5232, lng: -113.5263 },
        { id: 3, lat: 53.4668, lng: -113.5114 }
      ]
    end

    let(:distance_matrix_response) do
      {
        "status" => "OK",
        "rows" => [
          {
            "elements" => [
              { "status" => "OK", "distance" => { "value" => 0 }, "duration" => { "value" => 0 }, "duration_in_traffic" => { "value" => 0 } },
              { "status" => "OK", "distance" => { "value" => 3500 }, "duration" => { "value" => 600 }, "duration_in_traffic" => { "value" => 720 } },
              { "status" => "OK", "distance" => { "value" => 8900 }, "duration" => { "value" => 1200 }, "duration_in_traffic" => { "value" => 1500 } }
            ]
          },
          {
            "elements" => [
              { "status" => "OK", "distance" => { "value" => 3600 }, "duration" => { "value" => 620 }, "duration_in_traffic" => { "value" => 750 } },
              { "status" => "OK", "distance" => { "value" => 0 }, "duration" => { "value" => 0 }, "duration_in_traffic" => { "value" => 0 } },
              { "status" => "OK", "distance" => { "value" => 7200 }, "duration" => { "value" => 1100 }, "duration_in_traffic" => { "value" => 1350 } }
            ]
          },
          {
            "elements" => [
              { "status" => "OK", "distance" => { "value" => 9100 }, "duration" => { "value" => 1250 }, "duration_in_traffic" => { "value" => 1550 } },
              { "status" => "OK", "distance" => { "value" => 7400 }, "duration" => { "value" => 1150 }, "duration_in_traffic" => { "value" => 1400 } },
              { "status" => "OK", "distance" => { "value" => 0 }, "duration" => { "value" => 0 }, "duration_in_traffic" => { "value" => 0 } }
            ]
          }
        ]
      }
    end

    before do
      Rails.cache.clear
      stub_request(:get, %r{maps.googleapis.com/maps/api/distancematrix/json})
        .to_return(status: 200, body: distance_matrix_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns distance data for all location pairs" do
      result = service.distance_matrix(locations)

      # Should have entries for all non-same pairs (3 * 2 = 6)
      expect(result.keys.count).to eq(6)
    end

    it "returns distance and duration for each pair" do
      result = service.distance_matrix(locations)

      key = "1:2"
      expect(result[key][:distance_meters]).to eq(3500)
      expect(result[key][:duration_seconds]).to eq(600)
      expect(result[key][:duration_in_traffic_seconds]).to eq(720)
    end

    it "includes location references" do
      result = service.distance_matrix(locations)

      key = "1:2"
      expect(result[key][:from_location][:id]).to eq(1)
      expect(result[key][:to_location][:id]).to eq(2)
    end

    it "does not include same-location pairs" do
      result = service.distance_matrix(locations)

      expect(result).not_to have_key("1:1")
      expect(result).not_to have_key("2:2")
      expect(result).not_to have_key("3:3")
    end

    it "returns empty hash for single location" do
      result = service.distance_matrix([locations.first])
      expect(result).to eq({})
    end

    context "with unreachable destinations" do
      let(:unreachable_response) do
        {
          "status" => "OK",
          "rows" => [
            {
              "elements" => [
                { "status" => "OK", "distance" => { "value" => 0 }, "duration" => { "value" => 0 } },
                { "status" => "NOT_FOUND" }
              ]
            },
            {
              "elements" => [
                { "status" => "NOT_FOUND" },
                { "status" => "OK", "distance" => { "value" => 0 }, "duration" => { "value" => 0 } }
              ]
            }
          ]
        }
      end

      before do
        Rails.cache.clear
        stub_request(:get, %r{maps.googleapis.com/maps/api/distancematrix/json})
          .to_return(status: 200, body: unreachable_response.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "handles NOT_FOUND status with infinity values" do
        result = service.distance_matrix([locations[0], locations[1]])

        key = "1:2"
        expect(result[key][:distance_meters]).to eq(Float::INFINITY)
        expect(result[key][:status]).to eq("NOT_FOUND")
      end
    end
  end

  describe "#directions" do
    subject(:service) { described_class.new(api_key: api_key) }

    let(:origin) { { lat: 53.5461, lng: -113.4938 } }
    let(:destination) { { lat: 53.5232, lng: -113.5263 } }
    let(:waypoints) { [{ lat: 53.4668, lng: -113.5114 }] }

    let(:directions_response) do
      {
        "status" => "OK",
        "routes" => [
          {
            "legs" => [
              {
                "distance" => { "value" => 5000 },
                "duration" => { "value" => 900 },
                "duration_in_traffic" => { "value" => 1100 },
                "start_address" => "Downtown Edmonton",
                "end_address" => "West Edmonton",
                "start_location" => { "lat" => 53.5461, "lng" => -113.4938 },
                "end_location" => { "lat" => 53.5232, "lng" => -113.5263 },
                "steps" => [
                  {
                    "distance" => { "value" => 500 },
                    "duration" => { "value" => 60 },
                    "html_instructions" => "Head north",
                    "maneuver" => "turn-right"
                  }
                ]
              }
            ],
            "waypoint_order" => [0],
            "overview_polyline" => { "points" => "abc123xyz" }
          }
        ]
      }
    end

    before do
      stub_request(:get, %r{maps.googleapis.com/maps/api/directions/json})
        .to_return(status: 200, body: directions_response.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns route details" do
      result = service.directions(origin: origin, destination: destination)

      expect(result[:distance_meters]).to eq(5000)
      expect(result[:duration_seconds]).to eq(900)
      expect(result[:duration_in_traffic_seconds]).to eq(1100)
      expect(result[:polyline]).to eq("abc123xyz")
    end

    it "includes leg details" do
      result = service.directions(origin: origin, destination: destination)

      leg = result[:legs].first
      expect(leg[:start_address]).to eq("Downtown Edmonton")
      expect(leg[:end_address]).to eq("West Edmonton")
      expect(leg[:steps]).to be_an(Array)
    end

    it "supports waypoints" do
      result = service.directions(origin: origin, destination: destination, waypoints: waypoints)

      expect(result[:waypoint_order]).to eq([0])
    end

    context "when no route found" do
      before do
        stub_request(:get, %r{maps.googleapis.com/maps/api/directions/json})
          .to_return(status: 200, body: { "status" => "OK", "routes" => [] }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns nil" do
        result = service.directions(origin: origin, destination: destination)
        expect(result).to be_nil
      end
    end
  end

  describe "#traffic_factor" do
    subject(:service) { described_class.new(api_key: api_key) }

    let(:origin) { { lat: 53.5461, lng: -113.4938 } }
    let(:destination) { { lat: 53.5232, lng: -113.5263 } }

    context "with traffic data" do
      before do
        # Stub for call WITH traffic (includes departure_time)
        stub_request(:get, %r{maps.googleapis.com/maps/api/distancematrix/json.*departure_time=now})
          .to_return(
            status: 200,
            body: {
              "status" => "OK",
              "rows" => [{ "elements" => [{ "status" => "OK", "duration" => { "value" => 600 }, "duration_in_traffic" => { "value" => 720 } }] }]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Stub for call WITHOUT traffic (no departure_time)
        stub_request(:get, %r{maps.googleapis.com/maps/api/distancematrix/json})
          .with { |request| !request.uri.query.include?("departure_time") }
          .to_return(
            status: 200,
            body: {
              "status" => "OK",
              "rows" => [{ "elements" => [{ "status" => "OK", "duration" => { "value" => 600 } }] }]
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "calculates traffic factor" do
        factor = service.traffic_factor(origin: origin, destination: destination)

        # 720/600 = 1.2
        expect(factor).to eq(1.2)
      end
    end

    context "when API fails" do
      before do
        stub_request(:get, %r{maps.googleapis.com/maps/api/distancematrix/json})
          .to_return(status: 200, body: { "status" => "ZERO_RESULTS" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns default factor of 1.0" do
        factor = service.traffic_factor(origin: origin, destination: destination)
        expect(factor).to eq(1.0)
      end
    end
  end

  describe "error handling" do
    subject(:service) { described_class.new(api_key: api_key) }

    context "HTTP error" do
      before do
        stub_request(:get, %r{maps.googleapis.com/maps/api/geocode/json})
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises ApiError" do
        Rails.cache.clear
        expect { service.geocode("test") }.to raise_error(GoogleMapsService::ApiError, /HTTP 500/)
      end
    end

    context "REQUEST_DENIED" do
      before do
        stub_request(:get, %r{maps.googleapis.com/maps/api/geocode/json})
          .to_return(status: 200, body: { "status" => "REQUEST_DENIED", "error_message" => "Invalid API key" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "raises ApiError with message" do
        Rails.cache.clear
        expect { service.geocode("test") }.to raise_error(GoogleMapsService::ApiError, /Request denied.*Invalid API key/)
      end
    end

    context "INVALID_REQUEST" do
      before do
        stub_request(:get, %r{maps.googleapis.com/maps/api/geocode/json})
          .to_return(status: 200, body: { "status" => "INVALID_REQUEST", "error_message" => "Bad parameters" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "raises InvalidRequestError" do
        Rails.cache.clear
        expect { service.geocode("test") }.to raise_error(GoogleMapsService::InvalidRequestError)
      end
    end

    context "timeout" do
      before do
        stub_request(:get, %r{maps.googleapis.com/maps/api/geocode/json})
          .to_timeout
      end

      it "retries and eventually raises error" do
        Rails.cache.clear
        expect { service.geocode("test") }.to raise_error(Faraday::ConnectionFailed)
      end
    end
  end

  describe "caching" do
    subject(:service) { described_class.new(api_key: api_key) }

    let(:geocode_response) do
      {
        "status" => "OK",
        "results" => [
          {
            "geometry" => { "location" => { "lat" => 53.5461, "lng" => -113.4938 } },
            "formatted_address" => "Edmonton",
            "place_id" => "test"
          }
        ]
      }
    end

    it "uses cache when available", :caching do
      # Enable memory store for this test
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      stub = stub_request(:get, %r{maps.googleapis.com/maps/api/geocode/json})
        .to_return(status: 200, body: geocode_response.to_json, headers: { "Content-Type" => "application/json" })

      # First call
      service.geocode("Edmonton Cache Test")

      # Second call should use cache - verify stub was only called once
      service.geocode("Edmonton Cache Test")

      expect(stub).to have_been_requested.once
    end

    it "generates correct cache key" do
      address = "123 Test Street"
      expected_key = "geocode:#{Digest::MD5.hexdigest(address)}"

      expect(Rails.cache).to receive(:fetch).with(expected_key, expires_in: 30.days)

      stub_request(:get, %r{maps.googleapis.com/maps/api/geocode/json})
        .to_return(status: 200, body: geocode_response.to_json, headers: { "Content-Type" => "application/json" })

      service.geocode(address)
    end
  end
end
