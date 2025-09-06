class CreateRoutes < ActiveRecord::Migration[8.0]
  def change
    create_table :routes do |t|
      t.references :account, null: false, foreign_key: true
      t.date :scheduled_date
      t.string :status
      t.integer :total_distance_meters
      t.integer :total_duration_seconds

      t.timestamps
    end
  end
end
