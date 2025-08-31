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

ActiveRecord::Schema[8.0].define(version: 2025_08_31_213446) do
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
    t.index ["account_id"], name: "index_staffs_on_account_id"
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
  add_foreign_key "service_types", "verticals"
  add_foreign_key "staffs", "accounts"
end
