class AddOptimizationJobToRoutes < ActiveRecord::Migration[8.0]
  def change
    add_reference :routes, :optimization_job, null: true, foreign_key: true
  end
end
