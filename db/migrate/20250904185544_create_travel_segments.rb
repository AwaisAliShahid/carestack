class CreateTravelSegments < ActiveRecord::Migration[8.0]
  def change
    create_table :travel_segments do |t|
      t.integer :from_appointment_id
      t.integer :to_appointment_id  
      t.integer :distance_meters
      t.integer :duration_seconds
      t.decimal :traffic_factor, precision: 3, scale: 2

      t.timestamps
    end

    add_foreign_key :travel_segments, :appointments, column: :from_appointment_id
    add_foreign_key :travel_segments, :appointments, column: :to_appointment_id
    add_index :travel_segments, :from_appointment_id
    add_index :travel_segments, :to_appointment_id
  end
end