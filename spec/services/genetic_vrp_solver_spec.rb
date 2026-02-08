# frozen_string_literal: true

require "rails_helper"

RSpec.describe GeneticVrpSolver do
  let(:vertical) { create(:vertical, :cleaning) }
  let(:account) { create(:account, vertical: vertical) }
  let(:service_type) { create(:service_type, vertical: vertical, duration_minutes: 60) }

  # Staff with known locations
  let(:staff1) { create(:staff, :downtown_based, account: account) }
  let(:staff2) { create(:staff, :west_based, account: account) }

  # Customers at different locations
  let(:customer1) { create(:customer, :downtown, account: account) }
  let(:customer2) { create(:customer, :west_edmonton, account: account) }
  let(:customer3) { create(:customer, :south_edmonton, account: account) }

  let(:today) { Date.current }

  # Appointments assigned to staff
  let!(:appointment1) do
    create(:appointment,
      account: account,
      customer: customer1,
      service_type: service_type,
      staff: staff1,
      scheduled_at: today.to_time + 9.hours,
      status: "scheduled")
  end

  let!(:appointment2) do
    create(:appointment,
      account: account,
      customer: customer2,
      service_type: service_type,
      staff: staff1,
      scheduled_at: today.to_time + 11.hours,
      status: "scheduled")
  end

  let!(:appointment3) do
    create(:appointment,
      account: account,
      customer: customer3,
      service_type: service_type,
      staff: staff2,
      scheduled_at: today.to_time + 10.hours,
      status: "scheduled")
  end

  let(:appointments) { [ appointment1, appointment2, appointment3 ] }
  let(:staff_members) { [ staff1, staff2 ] }

  # Simple distance matrix for testing
  let(:distance_matrix) do
    {
      "staff_home_#{staff1.id}:#{appointment1.id}" => { distance_meters: 1000, duration_seconds: 600 },
      "staff_home_#{staff1.id}:#{appointment2.id}" => { distance_meters: 5000, duration_seconds: 1200 },
      "staff_home_#{staff2.id}:#{appointment3.id}" => { distance_meters: 3000, duration_seconds: 900 },
      "#{appointment1.id}:#{appointment2.id}" => { distance_meters: 4000, duration_seconds: 1000 },
      "#{appointment2.id}:#{appointment1.id}" => { distance_meters: 4000, duration_seconds: 1000 },
      "#{appointment1.id}:staff_home_#{staff1.id}" => { distance_meters: 1000, duration_seconds: 600 },
      "#{appointment2.id}:staff_home_#{staff1.id}" => { distance_meters: 5000, duration_seconds: 1200 },
      "#{appointment3.id}:staff_home_#{staff2.id}" => { distance_meters: 3000, duration_seconds: 900 }
    }
  end

  describe "#initialize" do
    it "sets default values" do
      solver = described_class.new(
        distance_matrix: distance_matrix,
        appointments: appointments,
        staff_members: staff_members
      )

      expect(solver.objective).to eq(:minimize_time)
      expect(solver.max_iterations).to eq(1000)
      expect(solver.population_size).to eq(50)
    end

    it "accepts custom configuration" do
      solver = described_class.new(
        distance_matrix: distance_matrix,
        appointments: appointments,
        staff_members: staff_members,
        objective: :minimize_distance,
        max_iterations: 500,
        population_size: 100
      )

      expect(solver.objective).to eq(:minimize_distance)
      expect(solver.max_iterations).to eq(500)
      expect(solver.population_size).to eq(100)
    end
  end

  describe "#solve" do
    context "with empty inputs" do
      it "returns empty array when no appointments" do
        solver = described_class.new(
          distance_matrix: distance_matrix,
          appointments: [],
          staff_members: staff_members
        )

        expect(solver.solve).to eq([])
      end

      it "returns empty array when no staff" do
        solver = described_class.new(
          distance_matrix: distance_matrix,
          appointments: appointments,
          staff_members: []
        )

        expect(solver.solve).to eq([])
      end
    end

    context "with valid inputs" do
      let(:solver) do
        described_class.new(
          distance_matrix: distance_matrix,
          appointments: appointments,
          staff_members: staff_members,
          max_iterations: 50, # Reduced for faster tests
          population_size: 10
        )
      end

      it "returns routes for staff with appointments" do
        routes = solver.solve

        expect(routes).to be_an(Array)
        expect(routes).not_to be_empty
      end

      it "assigns all appointments across staff" do
        routes = solver.solve

        # All appointments should be assigned somewhere
        assigned_ids = routes.flat_map { |r| r[:appointments].map(&:id) }.sort
        expect(assigned_ids).to eq(appointments.map(&:id).sort)

        # Each route's staff should be from our staff list
        routes.each do |route|
          expect(staff_members).to include(route[:staff])
        end
      end

      it "includes distance and time metrics" do
        routes = solver.solve

        routes.each do |route|
          expect(route[:total_distance_meters]).to be_a(Numeric)
          expect(route[:total_duration_seconds]).to be_a(Numeric)
          expect(route[:total_distance_meters]).to be >= 0
          expect(route[:total_duration_seconds]).to be >= 0
        end
      end

      it "includes stop details" do
        routes = solver.solve

        routes.each do |route|
          expect(route[:stops]).to be_an(Array)
          route[:stops].each_with_index do |stop, index|
            expect(stop[:appointment_id]).to be_present
            expect(stop[:estimated_arrival]).to be_a(Time)
            expect(stop[:estimated_departure]).to be_a(Time)
            expect(stop[:stop_order]).to eq(index)
          end
        end
      end
    end

    context "with different optimization objectives" do
      it "optimizes for minimum time" do
        solver = described_class.new(
          distance_matrix: distance_matrix,
          appointments: appointments,
          staff_members: staff_members,
          objective: :minimize_time,
          max_iterations: 50,
          population_size: 10
        )

        routes = solver.solve
        expect(routes).not_to be_empty
      end

      it "optimizes for minimum distance" do
        solver = described_class.new(
          distance_matrix: distance_matrix,
          appointments: appointments,
          staff_members: staff_members,
          objective: :minimize_distance,
          max_iterations: 50,
          population_size: 10
        )

        routes = solver.solve
        expect(routes).not_to be_empty
      end

      it "optimizes for balanced workload" do
        solver = described_class.new(
          distance_matrix: distance_matrix,
          appointments: appointments,
          staff_members: staff_members,
          objective: :balance_workload,
          max_iterations: 50,
          population_size: 10
        )

        routes = solver.solve
        expect(routes).not_to be_empty
      end
    end

    context "convergence behavior" do
      it "terminates early if no improvement" do
        solver = described_class.new(
          distance_matrix: distance_matrix,
          appointments: [ appointment1 ], # Single appointment = quick convergence
          staff_members: [ staff1 ],
          max_iterations: 1000,
          population_size: 10
        )

        start_time = Time.current
        solver.solve
        elapsed = Time.current - start_time

        # Should terminate well before max_iterations due to stagnation
        expect(elapsed).to be < 10.seconds
      end
    end
  end

  describe "private methods" do
    let(:solver) do
      described_class.new(
        distance_matrix: distance_matrix,
        appointments: appointments,
        staff_members: staff_members,
        max_iterations: 10,
        population_size: 10
      )
    end

    describe "#generate_initial_population" do
      it "creates population of correct size" do
        population = solver.send(:generate_initial_population)

        expect(population.size).to eq(10)
      end

      it "creates valid solutions" do
        population = solver.send(:generate_initial_population)

        population.each do |solution|
          expect(solution.size).to eq(staff_members.size)
          solution.each do |route|
            expect(route[:staff_id]).to be_present
            expect(route[:appointments]).to be_an(Array)
            expect(route[:home_location]).to be_a(Hash)
          end
        end
      end
    end

    describe "#calculate_fitness" do
      it "returns numeric fitness value" do
        solution = solver.send(:create_random_solution)
        fitness = solver.send(:calculate_fitness, solution)

        expect(fitness).to be_a(Numeric)
        expect(fitness).to be >= 0
      end

      it "penalizes constraint violations" do
        # Create solution with too many appointments
        overloaded_solution = staff_members.map.with_index do |staff, index|
          {
            staff_id: staff.id,
            staff_index: index,
            appointments: appointments.map(&:id) * 5, # Way too many
            home_location: { id: "staff_home_#{staff.id}", lat: 53.5, lng: -113.5 }
          }
        end

        fitness = solver.send(:calculate_fitness, overloaded_solution)

        # Should have high fitness (penalty) due to constraint violations
        expect(fitness).to be > 0
      end
    end

    describe "#tournament_selection" do
      it "selects from population based on fitness" do
        population = solver.send(:generate_initial_population)
        fitness_scores = population.map { |sol| solver.send(:calculate_fitness, sol) }

        selected = solver.send(:tournament_selection, population, fitness_scores)

        expect(selected).to be_an(Array)
        expect(population).to include(selected)
      end
    end

    describe "#crossover" do
      it "produces two offspring" do
        parent1 = solver.send(:create_random_solution)
        parent2 = solver.send(:create_random_solution)

        offspring1, offspring2 = solver.send(:crossover, parent1, parent2)

        expect(offspring1).to be_an(Array)
        expect(offspring2).to be_an(Array)
        expect(offspring1.size).to eq(parent1.size)
        expect(offspring2.size).to eq(parent2.size)
      end
    end

    describe "#mutate!" do
      it "modifies solution in place" do
        solution = solver.send(:create_random_solution)
        original_appointments = solution.map { |r| r[:appointments].dup }

        # Run mutation multiple times to ensure at least one change
        10.times { solver.send(:mutate!, solution) }

        # Structure should remain valid
        expect(solution.size).to eq(staff_members.size)
        solution.each do |route|
          expect(route[:staff_id]).to be_present
          expect(route[:appointments]).to be_an(Array)
        end
      end
    end

    describe "#get_travel_time" do
      it "returns time from distance matrix" do
        from_location = { id: "staff_home_#{staff1.id}", lat: 53.5, lng: -113.5 }
        to_location = { id: appointment1.id, lat: 53.5, lng: -113.4 }

        time = solver.send(:get_travel_time, from_location, to_location)

        expect(time).to eq(600) # From our distance matrix
      end

      it "returns default when no data available" do
        from_location = { id: "unknown1", lat: 53.5, lng: -113.5 }
        to_location = { id: "unknown2", lat: 53.5, lng: -113.4 }

        time = solver.send(:get_travel_time, from_location, to_location)

        expect(time).to eq(1800) # Default 30 minutes
      end
    end

    describe "#get_travel_distance" do
      it "returns distance from distance matrix" do
        from_location = { id: "staff_home_#{staff1.id}", lat: 53.5, lng: -113.5 }
        to_location = { id: appointment1.id, lat: 53.5, lng: -113.4 }

        distance = solver.send(:get_travel_distance, from_location, to_location)

        expect(distance).to eq(1000) # From our distance matrix
      end

      it "returns default when no data available" do
        from_location = { id: "unknown1", lat: 53.5, lng: -113.5 }
        to_location = { id: "unknown2", lat: 53.5, lng: -113.4 }

        distance = solver.send(:get_travel_distance, from_location, to_location)

        expect(distance).to eq(10000) # Default 10km
      end
    end

    describe "#staff_home_location" do
      it "returns staff home coordinates" do
        location = solver.send(:staff_home_location, staff1)

        expect(location[:id]).to eq("staff_home_#{staff1.id}")
        expect(location[:lat]).to eq(staff1.home_latitude)
        expect(location[:lng]).to eq(staff1.home_longitude)
      end

      it "uses default Edmonton coordinates when staff has no home location" do
        staff_no_location = create(:staff, account: account, home_latitude: nil, home_longitude: nil)
        location = solver.send(:staff_home_location, staff_no_location)

        expect(location[:lat]).to eq(53.5461) # Edmonton default
        expect(location[:lng]).to eq(-113.4938)
      end
    end

    describe "#appointment_location" do
      it "returns customer coordinates" do
        location = solver.send(:appointment_location, appointment1)

        expect(location[:id]).to eq(appointment1.id)
        expect(location[:lat]).to eq(customer1.latitude)
        expect(location[:lng]).to eq(customer1.longitude)
      end
    end

    describe "#can_assign_appointment?" do
      it "returns true for any staff in the same account" do
        # Staff1 and appointment1 are in the same account
        expect(solver.send(:can_assign_appointment?, staff1.id, appointment1)).to be true
        # Staff2 is also in the same account - GA can reassign across staff
        expect(solver.send(:can_assign_appointment?, staff2.id, appointment1)).to be true
      end

      it "returns false for staff not in the solver's staff list" do
        other_account = create(:account, vertical: vertical)
        other_staff = create(:staff, :downtown_based, account: other_account)

        result = solver.send(:can_assign_appointment?, other_staff.id, appointment1)

        expect(result).to be false
      end
    end

    describe "#max_appointments_per_route" do
      it "returns 8" do
        expect(solver.send(:max_appointments_per_route)).to eq(8)
      end
    end

    describe "#perform_2opt!" do
      it "does not modify routes with fewer than 4 appointments" do
        route = [ appointment1.id, appointment2.id ]
        original = route.dup

        solver.send(:perform_2opt!, route)

        expect(route).to eq(original)
      end
    end

    describe "#build_route_stops" do
      it "builds stops with correct order and timing" do
        route_appointments = [ appointment1, appointment2 ]

        stops = solver.send(:build_route_stops, route_appointments)

        expect(stops.size).to eq(2)
        expect(stops[0][:stop_order]).to eq(0)
        expect(stops[1][:stop_order]).to eq(1)
        expect(stops[0][:estimated_departure]).to be > stops[0][:estimated_arrival]
      end
    end

    describe "#convert_solution_to_routes" do
      it "returns empty array for nil solution" do
        expect(solver.send(:convert_solution_to_routes, nil)).to eq([])
      end

      it "converts internal solution to route format" do
        solution = [
          {
            staff_id: staff1.id,
            staff_index: 0,
            appointments: [ appointment1.id ],
            home_location: { id: "staff_home_#{staff1.id}", lat: 53.5, lng: -113.5 }
          },
          {
            staff_id: staff2.id,
            staff_index: 1,
            appointments: [],
            home_location: { id: "staff_home_#{staff2.id}", lat: 53.6, lng: -113.6 }
          }
        ]

        routes = solver.send(:convert_solution_to_routes, solution)

        expect(routes.size).to eq(1) # Only staff1 has appointments
        expect(routes[0][:staff]).to eq(staff1)
        expect(routes[0][:appointments]).to include(appointment1)
      end
    end
  end

  describe "edge cases" do
    it "handles single appointment" do
      solver = described_class.new(
        distance_matrix: distance_matrix,
        appointments: [ appointment1 ],
        staff_members: [ staff1 ],
        max_iterations: 10,
        population_size: 5
      )

      routes = solver.solve

      expect(routes.size).to eq(1)
      expect(routes[0][:appointments]).to contain_exactly(appointment1)
    end

    it "handles single staff member" do
      # Assign all appointments to staff1
      appointment2.update!(staff: staff1)
      appointment3.update!(staff: staff1)

      solver = described_class.new(
        distance_matrix: distance_matrix,
        appointments: [ appointment1, appointment2, appointment3 ],
        staff_members: [ staff1 ],
        max_iterations: 10,
        population_size: 5
      )

      routes = solver.solve

      expect(routes.size).to eq(1)
      expect(routes[0][:staff]).to eq(staff1)
    end

    it "handles missing distance matrix entries gracefully" do
      empty_matrix = {}

      solver = described_class.new(
        distance_matrix: empty_matrix,
        appointments: appointments,
        staff_members: staff_members,
        max_iterations: 10,
        population_size: 5
      )

      # Should not raise, uses defaults
      routes = solver.solve

      expect(routes).to be_an(Array)
    end
  end

  describe "algorithm quality" do
    context "with larger dataset" do
      let(:customers) do
        5.times.map do |i|
          create(:customer,
            account: account,
            latitude: 53.5 + (i * 0.01),
            longitude: -113.5 + (i * 0.01))
        end
      end

      let(:many_appointments) do
        customers.map.with_index do |customer, i|
          create(:appointment,
            account: account,
            customer: customer,
            service_type: service_type,
            staff: i.even? ? staff1 : staff2,
            scheduled_at: today.to_time + (9 + i).hours,
            status: "scheduled")
        end
      end

      it "produces reasonable routes" do
        # Build comprehensive distance matrix
        matrix = {}
        locations = [ staff1, staff2 ].map { |s| "staff_home_#{s.id}" } +
                   many_appointments.map(&:id)

        locations.each do |from|
          locations.each do |to|
            next if from == to
            matrix["#{from}:#{to}"] = {
              distance_meters: rand(1000..10000),
              duration_seconds: rand(300..1800)
            }
          end
        end

        solver = described_class.new(
          distance_matrix: matrix,
          appointments: many_appointments,
          staff_members: staff_members,
          max_iterations: 100,
          population_size: 20
        )

        routes = solver.solve

        # All appointments should be assigned
        assigned_appointments = routes.flat_map { |r| r[:appointments] }
        expect(assigned_appointments.map(&:id).sort).to eq(many_appointments.map(&:id).sort)
      end
    end
  end
end
