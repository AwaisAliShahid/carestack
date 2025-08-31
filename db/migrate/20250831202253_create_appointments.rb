class CreateAppointments < ActiveRecord::Migration[8.0]
  def change
    create_table :appointments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :service_type, null: false, foreign_key: true
      t.references :staff, null: false, foreign_key: true
      t.datetime :scheduled_at
      t.integer :duration_minutes
      t.string :status
      t.text :notes

      t.timestamps
    end
  end
end
