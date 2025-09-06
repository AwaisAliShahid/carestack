# frozen_string_literal: true

class GeneticVRPSolver
  attr_reader :distance_matrix, :appointments, :staff_members, :objective, :max_iterations, :population_size

  def initialize(distance_matrix:, appointments:, staff_members:, objective: :minimize_time, max_iterations: 1000, population_size: 50)
    @distance_matrix = distance_matrix
    @appointments = appointments
    @staff_members = staff_members
    @objective = objective
    @max_iterations = max_iterations
    @population_size = population_size
    @mutation_rate = 0.15
    @crossover_rate = 0.8
    @elite_size = (population_size * 0.2).to_i
  end

  def solve
    return [] if appointments.empty? || staff_members.empty?

    # Generate initial population
    population = generate_initial_population

    best_solution = nil
    best_fitness = Float::INFINITY
    stagnation_counter = 0
    max_stagnation = 100

    max_iterations.times do |generation|
      # Evaluate fitness for all solutions
      fitness_scores = population.map { |solution| calculate_fitness(solution) }
      
      # Track best solution
      current_best_index = fitness_scores.each_with_index.min_by { |fitness, _| fitness }[1]
      current_best_fitness = fitness_scores[current_best_index]
      
      if current_best_fitness < best_fitness
        best_fitness = current_best_fitness
        best_solution = population[current_best_index].deep_dup
        stagnation_counter = 0
      else
        stagnation_counter += 1
      end

      # Early termination if no improvement
      break if stagnation_counter >= max_stagnation

      # Create next generation
      population = evolve_population(population, fitness_scores)

      # Log progress periodically
      if generation % 100 == 0
        Rails.logger.info "Generation #{generation}: Best fitness = #{best_fitness.round(2)}"
      end
    end

    convert_solution_to_routes(best_solution)
  end

  private

  def generate_initial_population
    population = []

    # Generate diverse initial solutions
    population_size.times do
      solution = create_random_solution
      population << solution
    end

    # Add some greedy solutions for better starting point
    (population_size * 0.2).to_i.times do
      solution = create_greedy_solution
      population << solution
      population.pop # Remove a random solution
    end

    population
  end

  def create_random_solution
    # Randomly assign appointments to staff members
    solution = staff_members.map.with_index do |staff, staff_index|
      {
        staff_id: staff.id,
        staff_index: staff_index,
        appointments: [],
        home_location: staff_home_location(staff)
      }
    end

    # Randomly distribute appointments
    appointments.each do |appointment|
      available_staff = solution.select { |route| can_assign_appointment?(route[:staff_id], appointment) }
      next if available_staff.empty?

      random_staff = available_staff.sample
      random_staff[:appointments] << appointment.id
    end

    # Shuffle appointment order within each route
    solution.each { |route| route[:appointments].shuffle! }
    solution
  end

  def create_greedy_solution
    # Nearest neighbor heuristic
    solution = staff_members.map.with_index do |staff, staff_index|
      {
        staff_id: staff.id,
        staff_index: staff_index,
        appointments: [],
        home_location: staff_home_location(staff)
      }
    end

    unassigned = appointments.map(&:id)
    
    while unassigned.any?
      best_insertion = nil
      best_cost = Float::INFINITY

      solution.each do |route|
        next if route[:appointments].count >= max_appointments_per_route

        unassigned.each do |appointment_id|
          appointment = appointments.find { |a| a.id == appointment_id }
          next unless can_assign_appointment?(route[:staff_id], appointment)

          # Try inserting at each position
          (0..route[:appointments].length).each do |position|
            cost = insertion_cost(route, appointment_id, position)
            if cost < best_cost
              best_cost = cost
              best_insertion = { route: route, appointment_id: appointment_id, position: position }
            end
          end
        end
      end

      if best_insertion
        best_insertion[:route][:appointments].insert(best_insertion[:position], best_insertion[:appointment_id])
        unassigned.delete(best_insertion[:appointment_id])
      else
        break # No valid insertions found
      end
    end

    solution
  end

  def evolve_population(population, fitness_scores)
    new_population = []

    # Elitism: Keep best solutions
    elite_indices = fitness_scores.each_with_index.sort_by { |fitness, _| fitness }.first(elite_size).map { |_, index| index }
    elite_indices.each { |index| new_population << population[index].deep_dup }

    # Generate offspring through crossover and mutation
    while new_population.size < population_size
      # Tournament selection
      parent1 = tournament_selection(population, fitness_scores)
      parent2 = tournament_selection(population, fitness_scores)

      # Crossover
      if rand < crossover_rate
        offspring1, offspring2 = crossover(parent1, parent2)
      else
        offspring1, offspring2 = parent1.deep_dup, parent2.deep_dup
      end

      # Mutation
      mutate!(offspring1) if rand < mutation_rate
      mutate!(offspring2) if rand < mutation_rate

      new_population << offspring1
      new_population << offspring2 if new_population.size < population_size
    end

    new_population.first(population_size)
  end

  def tournament_selection(population, fitness_scores, tournament_size = 3)
    tournament_indices = (0...population.size).to_a.sample(tournament_size)
    best_index = tournament_indices.min_by { |index| fitness_scores[index] }
    population[best_index]
  end

  def crossover(parent1, parent2)
    offspring1 = deep_copy_solution(parent1)
    offspring2 = deep_copy_solution(parent2)

    # Order crossover for route sequences
    staff_members.each_with_index do |staff, staff_index|
      route1 = parent1[staff_index][:appointments]
      route2 = parent2[staff_index][:appointments]

      if route1.any? && route2.any?
        # Swap segments between routes
        point1 = rand(route1.length)
        point2 = rand(route1.length)
        point1, point2 = point2, point1 if point1 > point2

        segment1 = route1[point1..point2]
        segment2 = route2[point1..point2]

        # Remove conflicting appointments and insert segments
        offspring1[staff_index][:appointments] = (route1 - segment2) + segment2
        offspring2[staff_index][:appointments] = (route2 - segment1) + segment1
      end
    end

    [offspring1, offspring2]
  end

  def mutate!(solution)
    mutation_type = rand(4)

    case mutation_type
    when 0 # Swap appointments within a route
      route = solution.select { |r| r[:appointments].count > 1 }.sample
      return unless route

      i, j = route[:appointments].sample(2)
      route[:appointments][i], route[:appointments][j] = route[:appointments][j], route[:appointments][i]

    when 1 # Move appointment between routes
      from_route = solution.select { |r| r[:appointments].any? }.sample
      to_route = solution.sample
      return unless from_route && to_route && from_route != to_route

      appointment_id = from_route[:appointments].delete_at(rand(from_route[:appointments].length))
      appointment = appointments.find { |a| a.id == appointment_id }
      
      if can_assign_appointment?(to_route[:staff_id], appointment)
        to_route[:appointments] << appointment_id
      else
        from_route[:appointments] << appointment_id # Revert if invalid
      end

    when 2 # Reverse segment within route
      route = solution.select { |r| r[:appointments].count > 2 }.sample
      return unless route

      start_idx = rand(route[:appointments].length - 1)
      end_idx = start_idx + rand(route[:appointments].length - start_idx)
      route[:appointments][start_idx..end_idx] = route[:appointments][start_idx..end_idx].reverse

    when 3 # 2-opt improvement within route
      route = solution.select { |r| r[:appointments].count > 3 }.sample
      return unless route

      perform_2opt!(route[:appointments])
    end
  end

  def perform_2opt!(route_appointments)
    return if route_appointments.length < 4

    best_distance = calculate_route_distance(route_appointments)
    improved = true

    while improved
      improved = false

      (0...route_appointments.length - 1).each do |i|
        (i + 1...route_appointments.length).each do |j|
          # Swap edges
          new_route = route_appointments.dup
          new_route[i + 1..j] = new_route[i + 1..j].reverse

          new_distance = calculate_route_distance(new_route)
          if new_distance < best_distance
            route_appointments.replace(new_route)
            best_distance = new_distance
            improved = true
            break
          end
        end
        break if improved
      end
    end
  end

  def calculate_fitness(solution)
    total_cost = 0.0

    solution.each do |route|
      next if route[:appointments].empty?

      route_cost = case objective
                   when :minimize_time
                     calculate_total_travel_time(route)
                   when :minimize_distance
                     calculate_total_distance(route)
                   when :balance_workload
                     calculate_workload_balance_penalty(solution)
                   else
                     calculate_total_travel_time(route)
                   end

      # Add constraint violations as penalties
      route_cost += constraint_penalty(route)
      total_cost += route_cost
    end

    total_cost
  end

  def calculate_total_travel_time(route)
    return 0.0 if route[:appointments].empty?

    total_time = 0.0
    current_location = route[:home_location]

    route[:appointments].each do |appointment_id|
      appointment = appointments.find { |a| a.id == appointment_id }
      appointment_location = appointment_location(appointment)

      # Travel time to appointment
      travel_time = get_travel_time(current_location, appointment_location)
      total_time += travel_time

      # Service time
      total_time += appointment.service_type.duration_minutes * 60

      current_location = appointment_location
    end

    # Return home
    total_time += get_travel_time(current_location, route[:home_location])
    total_time
  end

  def calculate_total_distance(route)
    return 0.0 if route[:appointments].empty?

    total_distance = 0.0
    current_location = route[:home_location]

    route[:appointments].each do |appointment_id|
      appointment = appointments.find { |a| a.id == appointment_id }
      appointment_location = appointment_location(appointment)

      # Travel distance to appointment
      travel_distance = get_travel_distance(current_location, appointment_location)
      total_distance += travel_distance

      current_location = appointment_location
    end

    # Return home
    total_distance += get_travel_distance(current_location, route[:home_location])
    total_distance
  end

  def get_travel_time(from_location, to_location)
    key = "#{from_location[:id]}:#{to_location[:id]}"
    distance_data = distance_matrix[key]
    return 1800 unless distance_data # Default 30 min if no data

    distance_data[:duration_seconds] || 1800
  end

  def get_travel_distance(from_location, to_location)
    key = "#{from_location[:id]}:#{to_location[:id]}"
    distance_data = distance_matrix[key]
    return 10000 unless distance_data # Default 10km if no data

    distance_data[:distance_meters] || 10000
  end

  def constraint_penalty(route)
    penalty = 0.0

    # Max appointments per staff per day
    if route[:appointments].count > max_appointments_per_route
      penalty += (route[:appointments].count - max_appointments_per_route) * 3600
    end

    # Max working hours constraint
    total_work_time = calculate_total_travel_time(route)
    max_work_seconds = 8 * 3600 # 8 hours
    if total_work_time > max_work_seconds
      penalty += (total_work_time - max_work_seconds) * 2 # Double penalty for overtime
    end

    penalty
  end

  def calculate_workload_balance_penalty(solution)
    work_times = solution.map { |route| calculate_total_travel_time(route) }
    return 0.0 if work_times.empty?

    avg_time = work_times.sum / work_times.length.to_f
    variance = work_times.sum { |time| (time - avg_time) ** 2 } / work_times.length.to_f
    
    Math.sqrt(variance) # Standard deviation as penalty
  end

  def calculate_route_distance(appointment_ids)
    return 0.0 if appointment_ids.empty?

    total_distance = 0.0
    
    appointment_ids.each_cons(2) do |from_id, to_id|
      from_appointment = appointments.find { |a| a.id == from_id }
      to_appointment = appointments.find { |a| a.id == to_id }
      
      from_location = appointment_location(from_appointment)
      to_location = appointment_location(to_appointment)
      
      total_distance += get_travel_distance(from_location, to_location)
    end

    total_distance
  end

  def convert_solution_to_routes(solution)
    return [] unless solution

    routes = []

    solution.each do |route_data|
      next if route_data[:appointments].empty?

      staff = staff_members.find { |s| s.id == route_data[:staff_id] }
      route_appointments = route_data[:appointments].map do |appointment_id|
        appointments.find { |a| a.id == appointment_id }
      end

      total_distance = calculate_total_distance(route_data)
      total_time = calculate_total_travel_time(route_data)

      routes << {
        staff: staff,
        appointments: route_appointments,
        total_distance_meters: total_distance,
        total_duration_seconds: total_time,
        stops: build_route_stops(route_appointments)
      }
    end

    routes
  end

  def build_route_stops(route_appointments)
    stops = []
    current_time = Time.current.beginning_of_day + 8.hours

    route_appointments.each_with_index do |appointment, index|
      service_duration = appointment.service_type.duration_minutes.minutes

      stops << {
        appointment_id: appointment.id,
        estimated_arrival: current_time,
        estimated_departure: current_time + service_duration,
        stop_order: index
      }

      current_time += service_duration
      
      # Add travel time to next appointment if not last
      if index < route_appointments.length - 1
        next_appointment = route_appointments[index + 1]
        travel_time = get_travel_time(
          appointment_location(appointment),
          appointment_location(next_appointment)
        )
        current_time += travel_time.seconds
      end
    end

    stops
  end

  # Helper methods
  def staff_home_location(staff)
    {
      id: "staff_home_#{staff.id}",
      lat: staff.home_latitude || 53.5461, # Default Edmonton coordinates
      lng: staff.home_longitude || -113.4938
    }
  end

  def appointment_location(appointment)
    {
      id: appointment.id,
      lat: appointment.customer.latitude,
      lng: appointment.customer.longitude
    }
  end

  def can_assign_appointment?(staff_id, appointment)
    # Basic assignment rules - can be expanded
    appointment.staff_id == staff_id
  end

  def max_appointments_per_route
    8 # Maximum appointments per staff per day
  end

  def insertion_cost(route, appointment_id, position)
    # Calculate cost of inserting appointment at given position
    return 0.0 if route[:appointments].empty?

    appointment = appointments.find { |a| a.id == appointment_id }
    appointment_loc = appointment_location(appointment)

    if position == 0
      # Insert at beginning
      home_loc = route[:home_location]
      next_appointment = appointments.find { |a| a.id == route[:appointments][0] }
      next_loc = appointment_location(next_appointment)

      # Cost = home -> new + new -> next - home -> next
      new_cost = get_travel_time(home_loc, appointment_loc) + 
                 get_travel_time(appointment_loc, next_loc)
      old_cost = get_travel_time(home_loc, next_loc)
      
      new_cost - old_cost
    elsif position == route[:appointments].length
      # Insert at end
      prev_appointment = appointments.find { |a| a.id == route[:appointments][-1] }
      prev_loc = appointment_location(prev_appointment)
      home_loc = route[:home_location]

      # Cost = prev -> new + new -> home - prev -> home
      new_cost = get_travel_time(prev_loc, appointment_loc) + 
                 get_travel_time(appointment_loc, home_loc)
      old_cost = get_travel_time(prev_loc, home_loc)
      
      new_cost - old_cost
    else
      # Insert in middle
      prev_appointment = appointments.find { |a| a.id == route[:appointments][position - 1] }
      next_appointment = appointments.find { |a| a.id == route[:appointments][position] }
      
      prev_loc = appointment_location(prev_appointment)
      next_loc = appointment_location(next_appointment)

      # Cost = prev -> new + new -> next - prev -> next
      new_cost = get_travel_time(prev_loc, appointment_loc) + 
                 get_travel_time(appointment_loc, next_loc)
      old_cost = get_travel_time(prev_loc, next_loc)
      
      new_cost - old_cost
    end
  end

  def deep_copy_solution(solution)
    solution.map do |route|
      {
        staff_id: route[:staff_id],
        staff_index: route[:staff_index],
        appointments: route[:appointments].dup,
        home_location: route[:home_location].dup
      }
    end
  end
end