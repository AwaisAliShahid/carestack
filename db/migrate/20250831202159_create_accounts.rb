class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :name
      t.references :vertical, null: false, foreign_key: true
      t.string :email
      t.string :phone

      t.timestamps
    end
  end
end
