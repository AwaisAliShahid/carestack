class CreateServiceTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :service_types do |t|
      t.string :name
      t.references :vertical, null: false, foreign_key: true
      t.integer :duration_minutes
      t.boolean :requires_background_check
      t.decimal :min_staff_ratio

      t.timestamps
    end
  end
end
