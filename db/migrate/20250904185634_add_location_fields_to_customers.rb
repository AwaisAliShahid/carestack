class AddLocationFieldsToCustomers < ActiveRecord::Migration[8.0]
  def change
    add_column :customers, :latitude, :decimal
    add_column :customers, :longitude, :decimal
    add_column :customers, :geocoded_address, :string
  end
end
