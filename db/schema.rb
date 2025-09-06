# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_04_185646) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name"
    t.bigint "vertical_id", null: false
    t.string "email"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vertical_id"], name: "index_accounts_on_vertical_id"
  end

  create_table "appointments", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "customer_id", null: false
    t.bigint "service_type_id", null: false
    t.bigint "staff_id", null: false
    t.datetime "scheduled_at"
    t.integer "duration_minutes"
    t.string "status"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_appointments_on_account_id"
    t.index ["customer_id"], name: "index_appointments_on_customer_id"
    t.index ["service_type_id"], name: "index_appointments_on_service_type_id"
    t.index ["staff_id"], name: "index_appointments_on_staff_id"
  end

  create_table "customers", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.text "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "geocoded_address"
    t.index ["account_id"], name: "index_customers_on_account_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "optimization_jobs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.date "requested_date"
    t.string "status"
    t.json "parameters"
    t.json "result"
    t.datetime "processing_started_at"
    t.datetime "processing_completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_optimization_jobs_on_account_id"
  end

  create_table "route_stops", force: :cascade do |t|
    t.bigint "route_id", null: false
    t.bigint "appointment_id", null: false
    t.integer "stop_order"
    t.datetime "estimated_arrival"
    t.datetime "estimated_departure"
    t.datetime "actual_arrival"
    t.datetime "actual_departure"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_route_stops_on_appointment_id"
    t.index ["route_id"], name: "index_route_stops_on_route_id"
  end

  create_table "routes", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.date "scheduled_date"
    t.string "status"
    t.integer "total_distance_meters"
    t.integer "total_duration_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_routes_on_account_id"
  end

  create_table "service_types", force: :cascade do |t|
    t.string "name"
    t.bigint "vertical_id", null: false
    t.integer "duration_minutes"
    t.boolean "requires_background_check"
    t.decimal "min_staff_ratio"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vertical_id"], name: "index_service_types_on_vertical_id"
  end

  create_table "staffs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "phone"
    t.boolean "background_check_passed"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "home_latitude"
    t.decimal "home_longitude"
    t.integer "max_travel_radius_km"
    t.index ["account_id"], name: "index_staffs_on_account_id"
  end

  create_table "travel_segments", force: :cascade do |t|
    t.integer "from_appointment_id"
    t.integer "to_appointment_id"
    t.integer "distance_meters"
    t.integer "duration_seconds"
    t.decimal "traffic_factor", precision: 3, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_appointment_id"], name: "index_travel_segments_on_from_appointment_id"
    t.index ["to_appointment_id"], name: "index_travel_segments_on_to_appointment_id"
  end

  create_table "verticals", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.text "description"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "accounts", "verticals"
  add_foreign_key "appointments", "accounts"
  add_foreign_key "appointments", "customers"
  add_foreign_key "appointments", "service_types"
  add_foreign_key "appointments", "staffs"
  add_foreign_key "customers", "accounts"
  add_foreign_key "optimization_jobs", "accounts"
  add_foreign_key "route_stops", "appointments"
  add_foreign_key "route_stops", "routes"
  add_foreign_key "routes", "accounts"
  add_foreign_key "service_types", "verticals"
  add_foreign_key "staffs", "accounts"
  add_foreign_key "travel_segments", "appointments", column: "from_appointment_id"
  add_foreign_key "travel_segments", "appointments", column: "to_appointment_id"
end
