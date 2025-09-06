# frozen_string_literal: true

class SimpleRouteOptimizerService
  def initialize(account_id:, date:, optimization_type: "minimize_travel_time", staff_ids: [])
    @account = Account.find(account_id)
    @date = date
    @optimization_type = optimization_type
    @staff_ids = staff_ids
    @appointments = load_appointments
    @staff_members = load_staff_members
    @maps_service = MockGoogleMapsService.new
  end

  def optimize!
    return failed_result("No appointments to optimize") if @appointments.empty?
    return failed_result("No available staff") if @staff_members.empty?

    begin
      # Create optimization job record
      job = OptimizationJob.create!(
        account: @account,
        requested_date: @date,
        status: "processing",
        parameters: {
          optimization_type: @optimization_type,
          appointment_count: @appointments.count,
          staff_count: @staff_members.count
        },
        processing_started_at: Time.current
      )

      # Build location data
      locations = build_location_data

      # Get distance matrix
      distance_matrix = @maps_service.distance_matrix(locations)

      # Create optimized routes using simple nearest neighbor algorithm
      optimized_routes = create_optimized_routes(distance_matrix)

      # Save routes to database
      saved_routes = save_routes_to_database(optimized_routes)

      # Calculate savings
      savings = calculate_savings(saved_routes, distance_matrix)

      # Update job as completed
      job.update!(
        status: "completed",
        processing_completed_at: Time.current,
        result: {
          routes_created: saved_routes.count,
          total_appointments: @appointments.count,
          time_saved_hours: savings[:time_saved_hours],
          cost_savings: savings[:cost_savings],
          efficiency_improvement: savings[:efficiency_improvement],
          optimization_metrics: {
            total_distance_km: saved_routes.sum(&:total_distance_meters) / 1000.0,
            average_route_duration: saved_routes.sum(&:total_duration_seconds) / saved_routes.count.to_f,
            appointments_per_route: (@appointments.count / saved_routes.count.to_f).round(2)
          }
        }
      )

      success_result(saved_routes, job)

    rescue StandardError => e
      Rails.logger.error "Route optimization failed: #{e.message}"
      job&.update!(status: "failed", result: { error: e.message })
      failed_result(e.message)
    end
  end

  private

  def load_appointments
    scope = @account.appointments
                   .where(scheduled_at: @date.beginning_of_day..@date.end_of_day)
                   .where(status: [ "scheduled", "confirmed" ])
                   .includes(:customer, :service_type, :staff)

    scope = scope.where(staff_id: @staff_ids) if @staff_ids.present?
    scope.to_a
  end

  def load_staff_members
    staff_ids = @appointments.map(&:staff_id).compact.uniq
    staff_ids &= @staff_ids if @staff_ids.present?
    @account.staff.where(id: staff_ids).to_a
  end

  def build_location_data
    locations = []

    # Add appointment locations
    @appointments.each do |appointment|
      locations << {
        id: appointment.id,
        type: "appointment",
        lat: appointment.customer.latitude,
        lng: appointment.customer.longitude,
        staff_id: appointment.staff_id,
        duration_minutes: appointment.service_type.duration_minutes,
        appointment: appointment
      }
    end

    # Add staff home locations
    @staff_members.each do |staff|
      locations << {
        id: "staff_home_#{staff.id}",
        type: "staff_home",
        lat: staff.home_latitude,
        lng: staff.home_longitude,
        staff_id: staff.id,
        duration_minutes: 0,
        staff: staff
      }
    end

    locations
  end

  def create_optimized_routes(distance_matrix)
    routes = []

    @staff_members.each do |staff|
      staff_appointments = @appointments.select { |apt| apt.staff_id == staff.id }
      next if staff_appointments.empty?

      route = optimize_single_staff_route(staff, staff_appointments, distance_matrix)
      routes << route if route
    end

    routes
  end

  def optimize_single_staff_route(staff, appointments, distance_matrix)
    return nil if appointments.empty?

    # Start from staff home
    current_location_id = "staff_home_#{staff.id}"
    route_appointments = []
    unvisited = appointments.dup
    total_distance = 0
    total_time = 0
    current_time = @date.beginning_of_day + 8.hours # Start at 8 AM

    # Nearest neighbor algorithm
    while unvisited.any?
      nearest_appointment = nil
      shortest_distance = Float::INFINITY

      unvisited.each do |appointment|
        key = "#{current_location_id}:#{appointment.id}"
        distance_data = distance_matrix[key]

        if distance_data && distance_data[:duration_seconds] < shortest_distance
          shortest_distance = distance_data[:duration_seconds]
          nearest_appointment = appointment
        end
      end

      if nearest_appointment
        # Add travel time
        key = "#{current_location_id}:#{nearest_appointment.id}"
        travel_data = distance_matrix[key]

        if travel_data
          total_distance += travel_data[:distance_meters]
          total_time += travel_data[:duration_seconds]
          current_time += travel_data[:duration_seconds].seconds
        end

        # Add service time
        service_duration = nearest_appointment.service_type.duration_minutes * 60
        total_time += service_duration

        route_appointments << {
          appointment: nearest_appointment,
          estimated_arrival: current_time,
          estimated_departure: current_time + service_duration.seconds,
          travel_distance: travel_data&.dig(:distance_meters) || 0,
          travel_time: travel_data&.dig(:duration_seconds) || 0
        }

        current_time += service_duration.seconds
        current_location_id = nearest_appointment.id
        unvisited.delete(nearest_appointment)
      else
        break # No reachable appointments
      end
    end

    # Return to staff home
    return_key = "#{current_location_id}:staff_home_#{staff.id}"
    return_data = distance_matrix[return_key]
    if return_data
      total_distance += return_data[:distance_meters]
      total_time += return_data[:duration_seconds]
    end

    {
      staff: staff,
      appointments: route_appointments,
      total_distance_meters: total_distance,
      total_duration_seconds: total_time,
      start_time: @date.beginning_of_day + 8.hours,
      end_time: current_time
    }
  end

  def save_routes_to_database(optimized_routes)
    saved_routes = []

    optimized_routes.each do |route_data|
      route = Route.create!(
        account: @account,
        scheduled_date: @date,
        status: "optimized",
        total_distance_meters: route_data[:total_distance_meters],
        total_duration_seconds: route_data[:total_duration_seconds]
      )

      route_data[:appointments].each_with_index do |stop_data, index|
        RouteStop.create!(
          route: route,
          appointment: stop_data[:appointment],
          stop_order: index,
          estimated_arrival: stop_data[:estimated_arrival],
          estimated_departure: stop_data[:estimated_departure]
        )

        # Update appointment with new timing
        stop_data[:appointment].update!(
          scheduled_at: stop_data[:estimated_arrival]
        )
      end

      saved_routes << route
    end

    saved_routes
  end

  def calculate_savings(routes, distance_matrix)
    # Estimate baseline (random order) vs optimized
    baseline_time = estimate_baseline_time
    optimized_time = routes.sum(&:total_duration_seconds)

    time_saved_hours = [ (baseline_time - optimized_time) / 3600.0, 0 ].max
    cost_per_hour = 25.0
    cost_savings = time_saved_hours * cost_per_hour
    efficiency_improvement = baseline_time > 0 ? (time_saved_hours / (baseline_time / 3600.0)) * 100 : 0

    {
      time_saved_hours: time_saved_hours.round(2),
      cost_savings: cost_savings.round(2),
      efficiency_improvement: efficiency_improvement.round(2)
    }
  end

  def estimate_baseline_time
    # Rough estimate: 30 minutes average between appointments + service time
    travel_time = @appointments.count * 30 * 60 # 30 min per appointment travel
    service_time = @appointments.sum { |apt| apt.service_type.duration_minutes * 60 }
    travel_time + service_time
  end

  def success_result(routes, job)
    {
      success: true,
      routes: routes,
      optimization_job: job,
      metrics: job.result
    }
  end

  def failed_result(error_message)
    {
      success: false,
      error: error_message,
      optimization_job: nil
    }
  end
end
