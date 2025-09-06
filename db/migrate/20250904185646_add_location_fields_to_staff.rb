class AddLocationFieldsToStaff < ActiveRecord::Migration[8.0]
  def change
    add_column :staffs, :home_latitude, :decimal
    add_column :staffs, :home_longitude, :decimal
    add_column :staffs, :max_travel_radius_km, :integer
  end
end
