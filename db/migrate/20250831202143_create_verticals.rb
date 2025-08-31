class CreateVerticals < ActiveRecord::Migration[8.0]
  def change
    create_table :verticals do |t|
      t.string :name
      t.string :slug
      t.text :description
      t.boolean :active

      t.timestamps
    end
  end
end
