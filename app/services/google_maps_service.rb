# frozen_string_literal: true

class GoogleMapsService
  include HTTParty

  base_uri 'https://maps.googleapis.com/maps/api'
  
  def initialize
    @api_key = Rails.application.credentials.google_maps_api_key
    raise 'Google Maps API key not configured' if @api_key.blank?
  end

  def geocode(address)
    return nil if address.blank?

    Rails.cache.fetch("geocode:#{address}", expires_in: 30.days) do
      response = self.class.get('/geocode/json', {
        query: {
          address: address,
          key: @api_key
        }
      })

      if response.success? && response['status'] == 'OK'
        result = response['results'].first
        {
          lat: result['geometry']['location']['lat'],
          lng: result['geometry']['location']['lng'],
          formatted_address: result['formatted_address'],
          place_id: result['place_id']
        }
      else
        Rails.logger.warn "Geocoding failed for address '#{address}': #{response['status']}"
        nil
      end
    end
  end

  def distance_matrix(locations)
    return {} if locations.empty?

    # Split into manageable chunks (Google Maps API limit is 25 origins x 25 destinations)
    chunks = locations.each_slice(20).to_a
    distance_data = {}

    chunks.each do |origin_chunk|
      chunks.each do |destination_chunk|
        origins = origin_chunk.map { |loc| "#{loc[:lat]},#{loc[:lng]}" }.join('|')
        destinations = destination_chunk.map { |loc| "#{loc[:lat]},#{loc[:lng]}" }.join('|')

        cache_key = "distance_matrix:#{Digest::MD5.hexdigest("#{origins}:#{destinations}")}"
        
        chunk_data = Rails.cache.fetch(cache_key, expires_in: 4.hours) do
          response = self.class.get('/distancematrix/json', {
            query: {
              origins: origins,
              destinations: destinations,
              key: @api_key,
              mode: 'driving',
              departure_time: 'now',
              traffic_model: 'best_guess',
              units: 'metric'
            }
          })

          if response.success? && response['status'] == 'OK'
            parse_distance_matrix_response(response, origin_chunk, destination_chunk)
          else
            Rails.logger.error "Distance matrix API failed: #{response['status']}"
            {}
          end
        end

        distance_data.merge!(chunk_data)
      end
    end

    distance_data
  end

  def directions(origin, destination, waypoints = [])
    waypoint_string = waypoints.any? ? waypoints.map { |w| "#{w[:lat]},#{w[:lng]}" }.join('|') : nil
    
    response = self.class.get('/directions/json', {
      query: {
        origin: "#{origin[:lat]},#{origin[:lng]}",
        destination: "#{destination[:lat]},#{destination[:lng]}",
        waypoints: waypoint_string,
        optimize: waypoints.any?,
        key: @api_key,
        mode: 'driving',
        departure_time: 'now',
        traffic_model: 'best_guess'
      }.compact
    })

    if response.success? && response['status'] == 'OK'
      parse_directions_response(response)
    else
      Rails.logger.error "Directions API failed: #{response['status']}"
      nil
    end
  end

  def traffic_factor(origin, destination, departure_time = Time.current)
    # Get both current traffic and free-flow time
    queries = [
      { departure_time: 'now', traffic_model: 'best_guess' },
      { traffic_model: 'optimistic' }
    ]

    results = queries.map do |query_params|
      response = self.class.get('/distancematrix/json', {
        query: {
          origins: "#{origin[:lat]},#{origin[:lng]}",
          destinations: "#{destination[:lat]},#{destination[:lng]}",
          key: @api_key,
          mode: 'driving',
          units: 'metric'
        }.merge(query_params)
      })

      if response.success? && response['status'] == 'OK'
        element = response['rows'].first['elements'].first
        element['duration']['value'] if element['status'] == 'OK'
      end
    end

    traffic_duration, free_flow_duration = results

    if traffic_duration && free_flow_duration && free_flow_duration > 0
      (traffic_duration.to_f / free_flow_duration).round(2)
    else
      1.0 # Default to no traffic impact
    end
  end

  private

  def parse_distance_matrix_response(response, origins, destinations)
    data = {}
    
    response['rows'].each_with_index do |row, origin_index|
      origin_location = origins[origin_index]
      
      row['elements'].each_with_index do |element, dest_index|
        destination_location = destinations[dest_index]
        
        if element['status'] == 'OK'
          key = "#{origin_location[:id]}:#{destination_location[:id]}"
          data[key] = {
            distance_meters: element['distance']['value'],
            duration_seconds: element['duration']['value'],
            duration_in_traffic_seconds: element.dig('duration_in_traffic', 'value'),
            from_location: origin_location,
            to_location: destination_location
          }
        end
      end
    end
    
    data
  end

  def parse_directions_response(response)
    route = response['routes'].first
    return nil unless route

    legs = route['legs'].map do |leg|
      {
        start_location: leg['start_location'],
        end_location: leg['end_location'],
        distance_meters: leg['distance']['value'],
        duration_seconds: leg['duration']['value'],
        duration_in_traffic_seconds: leg.dig('duration_in_traffic', 'value'),
        steps: leg['steps'].map do |step|
          {
            distance_meters: step['distance']['value'],
            duration_seconds: step['duration']['value'],
            instructions: step['html_instructions'],
            maneuver: step['maneuver']
          }
        end
      }
    end

    {
      overview_polyline: route['overview_polyline']['points'],
      total_distance_meters: legs.sum { |leg| leg[:distance_meters] },
      total_duration_seconds: legs.sum { |leg| leg[:duration_seconds] },
      legs: legs,
      waypoint_order: route['waypoint_order']
    }
  end
end