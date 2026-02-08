class AddStaffIdToRoutes < ActiveRecord::Migration[8.0]
  def change
    add_reference :routes, :staff, null: true, foreign_key: true
  end
end
