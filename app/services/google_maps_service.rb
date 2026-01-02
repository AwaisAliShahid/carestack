# frozen_string_literal: true

class GoogleMapsService
  BASE_URL = "https://maps.googleapis.com"
  GEOCODE_PATH = "/maps/api/geocode/json"
  DISTANCE_MATRIX_PATH = "/maps/api/distancematrix/json"
  DIRECTIONS_PATH = "/maps/api/directions/json"

  class ApiError < StandardError; end
  class QuotaExceededError < ApiError; end
  class InvalidRequestError < ApiError; end

  def initialize(api_key: nil)
    @api_key = api_key ||
               Rails.application.credentials.dig(:google_maps, :api_key) ||
               ENV.fetch("GOOGLE_MAPS_API_KEY", nil)
    raise ArgumentError, "Google Maps API key is required" if @api_key.blank?
  end

  def geocode(address)
    return nil if address.blank?

    Rails.cache.fetch("geocode:#{Digest::MD5.hexdigest(address)}", expires_in: 30.days) do
      response = connection.get(GEOCODE_PATH) do |req|
        req.params["address"] = address
        req.params["key"] = @api_key
      end

      handle_response(response) do |data|
        result = data["results"].first
        return nil unless result

        location = result.dig("geometry", "location")
        {
          lat: location["lat"],
          lng: location["lng"],
          formatted_address: result["formatted_address"],
          place_id: result["place_id"]
        }
      end
    end
  end

  def reverse_geocode(lat:, lng:)
    cache_key = "reverse_geocode:#{lat.round(6)}_#{lng.round(6)}"

    Rails.cache.fetch(cache_key, expires_in: 30.days) do
      response = connection.get(GEOCODE_PATH) do |req|
        req.params["latlng"] = "#{lat},#{lng}"
        req.params["key"] = @api_key
      end

      handle_response(response) do |data|
        result = data["results"].first
        return nil unless result

        {
          formatted_address: result["formatted_address"],
          place_id: result["place_id"],
          address_components: parse_address_components(result["address_components"])
        }
      end
    end
  end

  def distance_matrix(locations)
    return {} if locations.size < 2

    # Split into manageable chunks (Google Maps API limit is 25 origins x 25 destinations)
    chunks = locations.each_slice(20).to_a
    distance_data = {}

    chunks.each do |origin_chunk|
      chunks.each do |destination_chunk|
        chunk_data = fetch_distance_matrix_chunk(origin_chunk, destination_chunk)
        distance_data.merge!(chunk_data)
      end
    end

    distance_data
  end

  def directions(origin:, destination:, waypoints: [], optimize_waypoints: false)
    response = connection.get(DIRECTIONS_PATH) do |req|
      req.params["origin"] = format_location(origin)
      req.params["destination"] = format_location(destination)
      req.params["mode"] = "driving"
      req.params["departure_time"] = "now"
      req.params["key"] = @api_key

      if waypoints.any?
        waypoint_str = waypoints.map { |wp| format_location(wp) }.join("|")
        waypoint_str = "optimize:true|#{waypoint_str}" if optimize_waypoints
        req.params["waypoints"] = waypoint_str
      end
    end

    handle_response(response) do |data|
      route = data["routes"].first
      return nil unless route

      parse_directions_response(route)
    end
  end

  def traffic_factor(origin:, destination:)
    # Get both current traffic and free-flow time
    traffic_duration = fetch_duration(origin, destination, with_traffic: true)
    free_flow_duration = fetch_duration(origin, destination, with_traffic: false)

    if traffic_duration && free_flow_duration && free_flow_duration > 0
      (traffic_duration.to_f / free_flow_duration).round(2)
    else
      1.0 # Default to no traffic impact
    end
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |faraday|
      faraday.request :retry, {
        max: 3,
        interval: 0.5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
      }
      faraday.response :json
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = 10
      faraday.options.open_timeout = 5
    end
  end

  def handle_response(response)
    unless response.success?
      Rails.logger.error "Google Maps API HTTP error: #{response.status}"
      raise ApiError, "HTTP #{response.status}: #{response.body}"
    end

    data = response.body
    status = data["status"]

    case status
    when "OK"
      yield(data)
    when "ZERO_RESULTS"
      nil
    when "OVER_QUERY_LIMIT", "OVER_DAILY_LIMIT"
      Rails.logger.error "Google Maps API quota exceeded"
      raise QuotaExceededError, "Google Maps API quota exceeded"
    when "REQUEST_DENIED"
      Rails.logger.error "Google Maps API request denied: #{data['error_message']}"
      raise ApiError, "Request denied: #{data['error_message']}"
    when "INVALID_REQUEST"
      Rails.logger.error "Google Maps API invalid request: #{data['error_message']}"
      raise InvalidRequestError, "Invalid request: #{data['error_message']}"
    else
      Rails.logger.error "Google Maps API unknown status: #{status}"
      raise ApiError, "Unknown status: #{status} - #{data['error_message']}"
    end
  end

  def fetch_distance_matrix_chunk(origin_chunk, destination_chunk)
    origins = origin_chunk.map { |loc| "#{loc[:lat]},#{loc[:lng]}" }.join("|")
    destinations = destination_chunk.map { |loc| "#{loc[:lat]},#{loc[:lng]}" }.join("|")

    cache_key = "distance_matrix:#{Digest::MD5.hexdigest("#{origins}:#{destinations}")}"

    Rails.cache.fetch(cache_key, expires_in: 4.hours) do
      response = connection.get(DISTANCE_MATRIX_PATH) do |req|
        req.params["origins"] = origins
        req.params["destinations"] = destinations
        req.params["mode"] = "driving"
        req.params["departure_time"] = "now"
        req.params["traffic_model"] = "best_guess"
        req.params["units"] = "metric"
        req.params["key"] = @api_key
      end

      handle_response(response) do |data|
        parse_distance_matrix(data, origin_chunk, destination_chunk)
      end
    end || {}
  end

  def parse_distance_matrix(data, origins, destinations)
    result = {}

    data["rows"].each_with_index do |row, origin_index|
      origin_location = origins[origin_index]

      row["elements"].each_with_index do |element, dest_index|
        destination_location = destinations[dest_index]

        # Skip same location pairs
        next if origin_location[:id] == destination_location[:id]

        key = "#{origin_location[:id]}:#{destination_location[:id]}"

        if element["status"] == "OK"
          result[key] = {
            distance_meters: element.dig("distance", "value"),
            duration_seconds: element.dig("duration", "value"),
            duration_in_traffic_seconds: element.dig("duration_in_traffic", "value") || element.dig("duration", "value"),
            from_location: origin_location,
            to_location: destination_location
          }
        else
          # Handle unreachable destinations
          result[key] = {
            distance_meters: Float::INFINITY,
            duration_seconds: Float::INFINITY,
            duration_in_traffic_seconds: Float::INFINITY,
            from_location: origin_location,
            to_location: destination_location,
            status: element["status"]
          }
        end
      end
    end

    result
  end

  def parse_directions_response(route)
    legs = route["legs"].map do |leg|
      {
        distance_meters: leg.dig("distance", "value"),
        duration_seconds: leg.dig("duration", "value"),
        duration_in_traffic_seconds: leg.dig("duration_in_traffic", "value") || leg.dig("duration", "value"),
        start_address: leg["start_address"],
        end_address: leg["end_address"],
        start_location: leg["start_location"],
        end_location: leg["end_location"],
        steps: parse_steps(leg["steps"])
      }
    end

    {
      distance_meters: legs.sum { |leg| leg[:distance_meters] },
      duration_seconds: legs.sum { |leg| leg[:duration_seconds] },
      duration_in_traffic_seconds: legs.sum { |leg| leg[:duration_in_traffic_seconds] },
      waypoint_order: route["waypoint_order"],
      polyline: route.dig("overview_polyline", "points"),
      legs: legs
    }
  end

  def parse_steps(steps)
    return [] unless steps

    steps.map do |step|
      {
        distance_meters: step.dig("distance", "value"),
        duration_seconds: step.dig("duration", "value"),
        instructions: step["html_instructions"],
        maneuver: step["maneuver"]
      }
    end
  end

  def parse_address_components(components)
    return {} unless components

    parsed = {}
    components.each do |component|
      types = component["types"]
      value = component["long_name"]

      parsed[:street_number] = value if types.include?("street_number")
      parsed[:route] = value if types.include?("route")
      parsed[:city] = value if types.include?("locality")
      parsed[:province] = value if types.include?("administrative_area_level_1")
      parsed[:country] = value if types.include?("country")
      parsed[:postal_code] = value if types.include?("postal_code")
    end

    parsed
  end

  def fetch_duration(origin, destination, with_traffic:)
    params = {
      "origins" => format_location(origin),
      "destinations" => format_location(destination),
      "mode" => "driving",
      "key" => @api_key
    }

    if with_traffic
      params["departure_time"] = "now"
      params["traffic_model"] = "best_guess"
    end

    response = connection.get(DISTANCE_MATRIX_PATH) do |req|
      params.each { |k, v| req.params[k] = v }
    end

    handle_response(response) do |data|
      element = data.dig("rows", 0, "elements", 0)
      return nil unless element && element["status"] == "OK"

      if with_traffic
        element.dig("duration_in_traffic", "value") || element.dig("duration", "value")
      else
        element.dig("duration", "value")
      end
    end
  end

  def format_location(location)
    if location.is_a?(Hash)
      "#{location[:lat]},#{location[:lng]}"
    else
      location.to_s
    end
  end
end
