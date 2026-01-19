# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Appointments: frequently queried by account, date range, and status
    add_index :appointments, [ :account_id, :scheduled_at, :status ],
              name: "index_appointments_on_account_date_status"

    # Customers: location-based queries for route optimization
    add_index :customers, [ :account_id, :latitude, :longitude ],
              name: "index_customers_on_account_location"

    # Staff: location-based queries for route optimization
    add_index :staffs, [ :account_id, :home_latitude, :home_longitude ],
              name: "index_staffs_on_account_home_location"

    # Routes: lookups by account, date, and status
    add_index :routes, [ :account_id, :scheduled_date, :status ],
              name: "index_routes_on_account_date_status"

    # Optimization jobs: lookups by account, date, and status
    add_index :optimization_jobs, [ :account_id, :requested_date, :status ],
              name: "index_optimization_jobs_on_account_date_status"
  end
end
