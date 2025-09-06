class CreateRouteStops < ActiveRecord::Migration[8.0]
  def change
    create_table :route_stops do |t|
      t.references :route, null: false, foreign_key: true
      t.references :appointment, null: false, foreign_key: true
      t.integer :stop_order
      t.datetime :estimated_arrival
      t.datetime :estimated_departure
      t.datetime :actual_arrival
      t.datetime :actual_departure

      t.timestamps
    end
  end
end
