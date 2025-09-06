# frozen_string_literal: true

# Mock service for development/testing without Google Maps API
class MockGoogleMapsService
  def geocode(address)
    # Mock geocoding for Edmonton area
    case address.downcase
    when /downtown/
      { lat: 53.5461, lng: -113.4938, formatted_address: "Downtown Edmonton, AB, Canada" }
    when /west/
      { lat: 53.5232, lng: -113.5263, formatted_address: "West Edmonton, AB, Canada" }
    when /north/
      { lat: 53.5731, lng: -113.4903, formatted_address: "North Edmonton, AB, Canada" }
    when /south/
      { lat: 53.4668, lng: -113.5114, formatted_address: "South Edmonton, AB, Canada" }
    when /east/
      { lat: 53.5586, lng: -113.4086, formatted_address: "East Edmonton, AB, Canada" }
    else
      # Random Edmonton area coordinates
      {
        lat: 53.5 + rand(0.2),
        lng: -113.5 + rand(0.2),
        formatted_address: "#{address}, Edmonton, AB, Canada"
      }
    end
  end

  def distance_matrix(locations)
    distance_data = {}

    locations.each do |from_location|
      locations.each do |to_location|
        next if from_location[:id] == to_location[:id]

        # Calculate approximate distance using Haversine formula
        distance_meters = haversine_distance(
          from_location[:lat], from_location[:lng],
          to_location[:lat], to_location[:lng]
        )

        # Estimate driving time (assuming 40 km/h average in city)
        duration_seconds = (distance_meters / 1000.0 / 40.0 * 3600).to_i

        key = "#{from_location[:id]}:#{to_location[:id]}"
        distance_data[key] = {
          distance_meters: distance_meters.to_i,
          duration_seconds: duration_seconds,
          duration_in_traffic_seconds: (duration_seconds * (1.0 + rand(0.5))).to_i, # Add random traffic
          from_location: from_location,
          to_location: to_location
        }
      end
    end

    distance_data
  end

  private

  def haversine_distance(lat1, lon1, lat2, lon2)
    # Earth's radius in meters
    r = 6_371_000

    # Convert degrees to radians
    lat1_rad = lat1 * Math::PI / 180
    lat2_rad = lat2 * Math::PI / 180
    delta_lat = (lat2 - lat1) * Math::PI / 180
    delta_lon = (lon2 - lon1) * Math::PI / 180

    # Haversine formula
    a = Math.sin(delta_lat/2) * Math.sin(delta_lat/2) +
        Math.cos(lat1_rad) * Math.cos(lat2_rad) *
        Math.sin(delta_lon/2) * Math.sin(delta_lon/2)

    c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))

    r * c
  end
end
