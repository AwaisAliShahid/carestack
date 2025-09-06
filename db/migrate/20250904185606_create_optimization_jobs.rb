class CreateOptimizationJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :optimization_jobs do |t|
      t.references :account, null: false, foreign_key: true
      t.date :requested_date
      t.string :status
      t.json :parameters
      t.json :result
      t.datetime :processing_started_at
      t.datetime :processing_completed_at

      t.timestamps
    end
  end
end
