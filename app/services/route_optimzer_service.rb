# frozen_string_literal: true

class RouteOptimizerService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :account_id, :integer
  attribute :date, :date
  attribute :optimization_type, :string, default: "minimize_travel_time"
  attribute :max_processing_time_seconds, :integer, default: 30
  attribute :staff_ids, :array, default: []

  OPTIMIZATION_TYPES = %w[
    minimize_travel_time
    minimize_total_cost
    balance_workload
    maximize_revenue
  ].freeze

  def initialize(attributes = {})
    super
    @account = Account.find(account_id)
    @appointments = load_appointments
    @staff_members = load_staff_members
    @optimization_job = create_optimization_job
  end

  def optimize!
    # Use simplified optimizer for now
    simple_optimizer = SimpleRouteOptimizerService.new(
      account_id: account_id,
      date: date,
      optimization_type: optimization_type,
      staff_ids: staff_ids
    )

    simple_optimizer.optimize!
  end

  private

  def load_appointments
    scope = @account.appointments
                   .where(scheduled_at: date.beginning_of_day..date.end_of_day)
                   .where(status: [ "scheduled", "confirmed" ])
                   .includes(:customer, :service_type, :staff)

    scope = scope.where(staff_id: staff_ids) if staff_ids.present?
    scope.to_a
  end

  def load_staff_members
    scope = @account.staff.where(id: @appointments.map(&:staff_id).compact.uniq)
    scope = scope.where(id: staff_ids) if staff_ids.present?
    scope.to_a
  end

  def create_optimization_job
    OptimizationJob.create!(
      account: @account,
      requested_date: date,
      status: "pending",
      parameters: {
        optimization_type: optimization_type,
        appointment_count: @appointments.count,
        staff_count: @staff_members.count,
        max_processing_time: max_processing_time_seconds
      }
    )
  end

  def geocode_missing_locations!
    customers_to_geocode = @appointments.map(&:customer)
                                      .select { |c| c.latitude.blank? || c.longitude.blank? }
                                      .uniq

    customers_to_geocode.each do |customer|
      coordinates = GoogleMapsService.new.geocode(customer.address)
      if coordinates
        customer.update!(
          latitude: coordinates[:lat],
          longitude: coordinates[:lng],
          geocoded_address: coordinates[:formatted_address]
        )
      end
    end
  end

  def calculate_distance_matrix
    locations = @appointments.map { |apt|
      {
        id: apt.id,
        lat: apt.customer.latitude,
        lng: apt.customer.longitude,
        staff_id: apt.staff_id,
        duration_minutes: apt.service_type.duration_minutes,
        revenue: apt.service_type.estimated_cost(hourly_rate_for_staff(apt.staff))
      }
    }

    # Add staff home locations as starting points
    @staff_members.each do |staff|
      locations << {
        id: "staff_home_#{staff.id}",
        lat: staff.home_latitude || @account.vertical.default_lat,
        lng: staff.home_longitude || @account.vertical.default_lng,
        staff_id: staff.id,
        duration_minutes: 0,
        revenue: 0,
        is_start_location: true
      }
    end

    GoogleMapsService.new.distance_matrix(locations)
  end

  def minimize_travel_time(distance_matrix)
    # Genetic Algorithm approach for Vehicle Routing Problem with Time Windows
    algorithm = GeneticVRPSolver.new(
      distance_matrix: distance_matrix,
      appointments: @appointments,
      staff_members: @staff_members,
      objective: :minimize_time,
      max_iterations: 1000,
      population_size: 100
    )

    algorithm.solve
  end

  def balance_workload(distance_matrix)
    # Balanced assignment ensuring fair distribution
    WorkloadBalancer.new(
      distance_matrix: distance_matrix,
      appointments: @appointments,
      staff_members: @staff_members
    ).optimize
  end

  def maximize_revenue(distance_matrix)
    # Prioritize high-value appointments while minimizing travel
    RevenueMaximizer.new(
      distance_matrix: distance_matrix,
      appointments: @appointments,
      staff_members: @staff_members
    ).optimize
  end

  def minimize_total_cost(distance_matrix)
    # Balance travel costs with opportunity costs
    CostMinimizer.new(
      distance_matrix: distance_matrix,
      appointments: @appointments,
      staff_members: @staff_members,
      fuel_cost_per_km: 0.15,
      hourly_wage_rates: calculate_wage_rates
    ).optimize
  end

  def create_route_records(optimized_routes)
    routes = []

    optimized_routes.each do |route_data|
      route = Route.create!(
        account: @account,
        scheduled_date: date,
        status: "optimized",
        total_distance_meters: route_data[:total_distance],
        total_duration_seconds: route_data[:total_duration]
      )

      route_data[:stops].each_with_index do |stop, index|
        RouteStop.create!(
          route: route,
          appointment_id: stop[:appointment_id],
          stop_order: index,
          estimated_arrival: stop[:estimated_arrival],
          estimated_departure: stop[:estimated_departure]
        )
      end

      routes << route
    end

    routes
  end

  def update_appointment_assignments(routes)
    routes.each do |route|
      route.route_stops.includes(:appointment).each do |stop|
        stop.appointment.update!(
          staff_id: route_staff_assignment[route.id],
          scheduled_at: stop.estimated_arrival
        )
      end
    end
  end

  def calculate_savings(routes)
    # Compare against baseline random assignment
    baseline_travel_time = estimate_baseline_travel_time
    optimized_travel_time = routes.sum(&:total_duration_seconds)

    time_saved_hours = (baseline_travel_time - optimized_travel_time) / 3600.0
    cost_per_hour = 25.0 # Average staff cost per hour

    {
      time_saved_hours: time_saved_hours.round(2),
      cost_savings: (time_saved_hours * cost_per_hour).round(2),
      efficiency_improvement: ((time_saved_hours / (baseline_travel_time / 3600.0)) * 100).round(2)
    }
  end

  def calculate_metrics(routes)
    {
      total_routes: routes.count,
      average_route_duration: routes.average(:total_duration_seconds),
      total_distance_km: routes.sum(:total_distance_meters) / 1000.0,
      appointments_per_route: (@appointments.count / routes.count.to_f).round(2)
    }
  end

  def hourly_rate_for_staff(staff)
    # Default rate logic - could be customized per staff/vertical
    case @account.vertical.slug
    when /cleaning/
      50.0
    when /elderly_care/
      65.0
    else
      55.0
    end
  end

  def update_job_status(status, result_data = {})
    @optimization_job.update!(
      status: status,
      result: result_data,
      processing_completed_at: (status.in?([ "completed", "failed" ]) ? Time.current : nil)
    )
  end

  def success_result(routes)
    {
      success: true,
      routes: routes,
      optimization_job: @optimization_job,
      metrics: @optimization_job.result
    }
  end

  def failed_result(error_message)
    {
      success: false,
      error: error_message,
      optimization_job: @optimization_job
    }
  end

  def estimate_baseline_travel_time
    # Rough estimate of random assignment travel time
    @appointments.count * 1800 # 30 minutes average travel between jobs
  end

  def calculate_wage_rates
    @staff_members.map { |staff| [ staff.id, hourly_rate_for_staff(staff) ] }.to_h
  end

  def route_staff_assignment
    @route_staff_assignment ||= {}
  end
end
