# frozen_string_literal: true

# CareStack Demo Data Seeds
# Run with: rails db:seed
#
# This creates a realistic demo dataset for showcasing the route optimization system.
# All data is idempotent - safe to run multiple times.

puts "=" * 60
puts "CareStack Database Seeding"
puts "=" * 60

# ==============================================================================
# VERTICALS - The different service industries CareStack supports
# ==============================================================================
puts "\n[1/6] Creating Verticals..."

verticals_data = [
  {
    name: "Cleaning Services",
    slug: "cleaning",
    description: "Professional cleaning services for homes and businesses",
    active: true
  },
  {
    name: "Elderly Care",
    slug: "elderly_care",
    description: "In-home care services for seniors including companionship, personal care, and medical assistance",
    active: true
  },
  {
    name: "Tutoring",
    slug: "tutoring",
    description: "Educational tutoring services for students of all ages",
    active: true
  },
  {
    name: "Home Repair",
    slug: "home_repair",
    description: "Home maintenance and repair services including plumbing, electrical, and general handyman work",
    active: true
  }
]

verticals = {}
verticals_data.each do |data|
  vertical = Vertical.find_or_create_by!(slug: data[:slug]) do |v|
    v.name = data[:name]
    v.description = data[:description]
    v.active = data[:active]
  end
  verticals[data[:slug].to_sym] = vertical
  puts "  - #{vertical.name}"
end

# ==============================================================================
# SERVICE TYPES - Services offered within each vertical
# ==============================================================================
puts "\n[2/6] Creating Service Types..."

service_types_data = {
  cleaning: [
    { name: "Basic House Cleaning", duration_minutes: 120, requires_background_check: false },
    { name: "Deep Cleaning", duration_minutes: 240, requires_background_check: false },
    { name: "Move-In/Move-Out Cleaning", duration_minutes: 300, requires_background_check: false },
    { name: "Post-Construction Cleanup", duration_minutes: 360, requires_background_check: true },
    { name: "Office Cleaning", duration_minutes: 180, requires_background_check: false }
  ],
  elderly_care: [
    { name: "Companion Care", duration_minutes: 240, requires_background_check: true, min_staff_ratio: 1.0 },
    { name: "Personal Care Assistance", duration_minutes: 120, requires_background_check: true, min_staff_ratio: 1.0 },
    { name: "Medication Reminders", duration_minutes: 60, requires_background_check: true, min_staff_ratio: 1.0 },
    { name: "Meal Preparation", duration_minutes: 90, requires_background_check: true, min_staff_ratio: 1.0 },
    { name: "24-Hour Care", duration_minutes: 1440, requires_background_check: true, min_staff_ratio: 2.0 }
  ],
  tutoring: [
    { name: "Elementary Math", duration_minutes: 60, requires_background_check: true },
    { name: "High School Math", duration_minutes: 90, requires_background_check: true },
    { name: "SAT/ACT Prep", duration_minutes: 120, requires_background_check: true },
    { name: "Reading & Writing", duration_minutes: 60, requires_background_check: true },
    { name: "Science Tutoring", duration_minutes: 90, requires_background_check: true }
  ],
  home_repair: [
    { name: "General Handyman", duration_minutes: 120, requires_background_check: false },
    { name: "Plumbing Repair", duration_minutes: 90, requires_background_check: false },
    { name: "Electrical Work", duration_minutes: 120, requires_background_check: true },
    { name: "HVAC Maintenance", duration_minutes: 180, requires_background_check: false },
    { name: "Appliance Repair", duration_minutes: 90, requires_background_check: false }
  ]
}

service_types = {}
service_types_data.each do |vertical_slug, services|
  vertical = verticals[vertical_slug]
  service_types[vertical_slug] = []

  services.each do |data|
    st = ServiceType.find_or_create_by!(name: data[:name], vertical: vertical) do |s|
      s.duration_minutes = data[:duration_minutes]
      s.requires_background_check = data[:requires_background_check]
      s.min_staff_ratio = data[:min_staff_ratio]
    end
    service_types[vertical_slug] << st
    puts "  - #{vertical.name}: #{st.name} (#{st.duration_minutes} min)"
  end
end

# ==============================================================================
# ACCOUNTS - Demo businesses using CareStack
# ==============================================================================
puts "\n[3/6] Creating Demo Accounts..."

accounts_data = [
  {
    name: "Sparkle Clean Edmonton",
    email: "info@sparkleclean.demo",
    phone: "780-555-0101",
    vertical: :cleaning
  },
  {
    name: "Golden Years Home Care",
    email: "care@goldenyears.demo",
    phone: "780-555-0102",
    vertical: :elderly_care
  },
  {
    name: "Bright Minds Tutoring",
    email: "learn@brightminds.demo",
    phone: "780-555-0103",
    vertical: :tutoring
  },
  {
    name: "Fix-It Pro Services",
    email: "service@fixitpro.demo",
    phone: "780-555-0104",
    vertical: :home_repair
  }
]

accounts = {}
accounts_data.each do |data|
  account = Account.find_or_create_by!(email: data[:email]) do |a|
    a.name = data[:name]
    a.phone = data[:phone]
    a.vertical = verticals[data[:vertical]]
  end
  accounts[data[:vertical]] = account
  puts "  - #{account.name} (#{account.vertical.name})"
end

# ==============================================================================
# STAFF - Employees for each business (Edmonton-based locations)
# ==============================================================================
puts "\n[4/6] Creating Staff Members..."

# Edmonton area locations for realistic routing
edmonton_locations = {
  downtown: { lat: 53.5461, lng: -113.4938, area: "Downtown Edmonton" },
  west: { lat: 53.5232, lng: -113.6263, area: "West Edmonton" },
  south: { lat: 53.4668, lng: -113.5114, area: "South Edmonton" },
  north: { lat: 53.6120, lng: -113.4985, area: "North Edmonton" },
  sherwood_park: { lat: 53.5412, lng: -113.3180, area: "Sherwood Park" },
  st_albert: { lat: 53.6301, lng: -113.6258, area: "St. Albert" }
}

staff_data = {
  cleaning: [
    { first: "Maria", last: "Garcia", email: "maria@sparkleclean.demo", location: :downtown, bg_check: true, radius: 30 },
    { first: "James", last: "Wilson", email: "james@sparkleclean.demo", location: :west, bg_check: true, radius: 25 },
    { first: "Sarah", last: "Johnson", email: "sarah@sparkleclean.demo", location: :south, bg_check: false, radius: 20 },
    { first: "Michael", last: "Brown", email: "michael@sparkleclean.demo", location: :north, bg_check: true, radius: 35 }
  ],
  elderly_care: [
    { first: "Emily", last: "Davis", email: "emily@goldenyears.demo", location: :downtown, bg_check: true, radius: 25 },
    { first: "Robert", last: "Martinez", email: "robert@goldenyears.demo", location: :west, bg_check: true, radius: 30 },
    { first: "Jennifer", last: "Anderson", email: "jennifer@goldenyears.demo", location: :south, bg_check: true, radius: 20 },
    { first: "David", last: "Taylor", email: "david@goldenyears.demo", location: :sherwood_park, bg_check: true, radius: 35 }
  ],
  tutoring: [
    { first: "Amanda", last: "Thomas", email: "amanda@brightminds.demo", location: :downtown, bg_check: true, radius: 40 },
    { first: "Christopher", last: "Lee", email: "chris@brightminds.demo", location: :st_albert, bg_check: true, radius: 30 },
    { first: "Jessica", last: "White", email: "jessica@brightminds.demo", location: :south, bg_check: true, radius: 25 }
  ],
  home_repair: [
    { first: "Daniel", last: "Harris", email: "daniel@fixitpro.demo", location: :west, bg_check: false, radius: 50 },
    { first: "Matthew", last: "Clark", email: "matthew@fixitpro.demo", location: :north, bg_check: true, radius: 45 },
    { first: "Andrew", last: "Lewis", email: "andrew@fixitpro.demo", location: :sherwood_park, bg_check: false, radius: 40 }
  ]
}

staff_members = {}
staff_data.each do |vertical_slug, staff_list|
  account = accounts[vertical_slug]
  staff_members[vertical_slug] = []

  staff_list.each do |data|
    loc = edmonton_locations[data[:location]]
    staff = Staff.find_or_create_by!(email: data[:email]) do |s|
      s.account = account
      s.first_name = data[:first]
      s.last_name = data[:last]
      s.phone = "780-555-#{rand(1000..9999)}"
      s.background_check_passed = data[:bg_check]
      s.home_latitude = loc[:lat]
      s.home_longitude = loc[:lng]
      s.max_travel_radius_km = data[:radius]
    end
    staff_members[vertical_slug] << staff
    puts "  - #{staff.first_name} #{staff.last_name} (#{account.name}) - #{loc[:area]}"
  end
end

# ==============================================================================
# CUSTOMERS - Clients for each business (Edmonton area)
# ==============================================================================
puts "\n[5/6] Creating Customers..."

# Customer locations spread across Edmonton
customer_locations = [
  { lat: 53.5445, lng: -113.4909, address: "10234 104 Street NW, Edmonton, AB" },
  { lat: 53.5401, lng: -113.5065, address: "10425 118 Street NW, Edmonton, AB" },
  { lat: 53.5228, lng: -113.5214, address: "8720 149 Street NW, Edmonton, AB" },
  { lat: 53.4722, lng: -113.5067, address: "2331 66 Street NW, Edmonton, AB" },
  { lat: 53.5563, lng: -113.4876, address: "11456 97 Street NW, Edmonton, AB" },
  { lat: 53.5089, lng: -113.4978, address: "7623 109 Street NW, Edmonton, AB" },
  { lat: 53.5341, lng: -113.5456, address: "10890 156 Street NW, Edmonton, AB" },
  { lat: 53.4891, lng: -113.4723, address: "5234 91 Street NW, Edmonton, AB" },
  { lat: 53.5678, lng: -113.5234, address: "12567 127 Street NW, Edmonton, AB" },
  { lat: 53.4567, lng: -113.5678, address: "1890 178 Street NW, Edmonton, AB" },
  { lat: 53.5890, lng: -113.4567, address: "13456 82 Street NW, Edmonton, AB" },
  { lat: 53.5123, lng: -113.5890, address: "6789 170 Street NW, Edmonton, AB" }
]

customer_names = [
  { first: "John", last: "Smith" },
  { first: "Patricia", last: "Johnson" },
  { first: "William", last: "Williams" },
  { first: "Linda", last: "Brown" },
  { first: "Richard", last: "Jones" },
  { first: "Barbara", last: "Miller" },
  { first: "Joseph", last: "Davis" },
  { first: "Susan", last: "Wilson" },
  { first: "Thomas", last: "Moore" },
  { first: "Margaret", last: "Taylor" },
  { first: "Charles", last: "Anderson" },
  { first: "Dorothy", last: "Thomas" }
]

customers = {}
[ :cleaning, :elderly_care, :tutoring, :home_repair ].each do |vertical_slug|
  account = accounts[vertical_slug]
  customers[vertical_slug] = []

  # Each account gets 8-10 customers
  customer_count = vertical_slug == :cleaning ? 10 : 8

  customer_count.times do |i|
    loc = customer_locations[i % customer_locations.length]
    name = customer_names[i % customer_names.length]

    email = "#{name[:first].downcase}.#{name[:last].downcase}.#{vertical_slug}@customer.demo"

    customer = Customer.find_or_create_by!(email: email, account: account) do |c|
      c.first_name = name[:first]
      c.last_name = name[:last]
      c.phone = "780-#{rand(200..899)}-#{rand(1000..9999)}"
      c.address = loc[:address]
      c.latitude = loc[:lat] + rand(-0.01..0.01) # Slight variation
      c.longitude = loc[:lng] + rand(-0.01..0.01)
      c.geocoded_address = loc[:address]
    end
    customers[vertical_slug] << customer
  end

  puts "  - #{account.name}: #{customers[vertical_slug].length} customers"
end

# ==============================================================================
# APPOINTMENTS - Demo appointments for route optimization
# ==============================================================================
puts "\n[6/6] Creating Demo Appointments..."

# Create appointments for today and tomorrow for the cleaning and elderly care businesses
# These are the primary demo verticals (relevant to ZenMaid-like businesses)

today = Date.current
tomorrow = Date.current + 1.day

appointments_created = 0

[ :cleaning, :elderly_care ].each do |vertical_slug|
  account = accounts[vertical_slug]
  account_staff = staff_members[vertical_slug]
  account_customers = customers[vertical_slug]
  account_services = service_types[vertical_slug]

  [ today, tomorrow ].each do |date|
    # Create 6-8 appointments per day for route optimization demo
    appointment_count = vertical_slug == :cleaning ? 8 : 6

    appointment_count.times do |i|
      customer = account_customers[i % account_customers.length]
      staff = account_staff[i % account_staff.length]
      service = account_services.first(3).sample # Use first 3 service types

      # Spread appointments throughout the day (8 AM to 5 PM)
      hour = 8 + (i * 1.5).to_i
      scheduled_time = date.to_time.change(hour: hour, min: [ 0, 30 ].sample)

      # Skip if appointment already exists
      existing = Appointment.find_by(
        account: account,
        customer: customer,
        scheduled_at: scheduled_time.beginning_of_hour..scheduled_time.end_of_hour
      )

      next if existing

      appointment = Appointment.create!(
        account: account,
        customer: customer,
        staff: staff,
        service_type: service,
        scheduled_at: scheduled_time,
        duration_minutes: service.duration_minutes,
        status: date == today ? "confirmed" : "scheduled",
        notes: [ "Regular appointment", "First-time customer", "Repeat client", nil ].sample
      )
      appointments_created += 1
    end
  end

  total_for_account = Appointment.where(account: account, scheduled_at: today.beginning_of_day..tomorrow.end_of_day).count
  puts "  - #{account.name}: #{total_for_account} appointments (today & tomorrow)"
end

# ==============================================================================
# SUMMARY
# ==============================================================================
puts "\n" + "=" * 60
puts "Seeding Complete!"
puts "=" * 60
puts "\nCreated:"
puts "  - #{Vertical.count} verticals"
puts "  - #{ServiceType.count} service types"
puts "  - #{Account.count} accounts"
puts "  - #{Staff.count} staff members"
puts "  - #{Customer.count} customers"
puts "  - #{Appointment.count} appointments"

puts "\nDemo Accounts for Testing:"
accounts.each do |vertical, account|
  staff_count = Staff.where(account: account).count
  customer_count = Customer.where(account: account).count
  appt_count = Appointment.where(account: account).count
  puts "  - #{account.name}"
  puts "    Email: #{account.email}"
  puts "    Staff: #{staff_count}, Customers: #{customer_count}, Appointments: #{appt_count}"
end

puts "\nRoute Optimization Demo:"
puts "  Run the following GraphQL mutation to optimize routes for Sparkle Clean Edmonton:"
puts ""
puts '  mutation {'
puts '    optimizeRoutes(input: {'
puts "      accountId: #{accounts[:cleaning].id}"
puts '      date: "' + today.to_s + '"'
puts '    }) {'
puts '      optimizationJob { id status }'
puts '      routes { id totalDistanceMeters totalDurationSeconds }'
puts '    }'
puts '  }'
puts ""
puts "=" * 60
