# frozen_string_literal: true

module Mutations
  class OptimizeRoutes < BaseMutation
    description "Optimize routes for appointments on a given date using advanced algorithms"

    argument :account_id, ID, required: true
    argument :date, GraphQL::Types::ISO8601Date, required: true
    argument :optimization_type, String, required: false, default_value: "minimize_travel_time"
    argument :staff_ids, [ ID ], required: false
    argument :force_reoptimization, Boolean, required: false, default_value: false
    argument :async, Boolean, required: false, default_value: false,
             description: "Run optimization in background. Returns immediately with pending job."

    field :optimization_job, Types::OptimizationJobType, null: true
    field :routes, [ Types::RouteType ], null: true
    field :estimated_savings, Types::OptimizationSavingsType, null: true
    field :errors, [ String ], null: false

    def resolve(account_id:, date:, optimization_type: "minimize_travel_time", staff_ids: nil, force_reoptimization: false, async: false)
      begin
        account = Account.find(account_id)

        # Check if optimization already exists for this date
        existing_job = OptimizationJob.where(
          account: account,
          requested_date: date,
          status: "completed"
        ).order(created_at: :desc).first

        if existing_job && !force_reoptimization
          return {
            optimization_job: existing_job,
            routes: existing_job.routes,
            estimated_savings: extract_savings_from_job(existing_job),
            errors: []
          }
        end

        # Validate optimization type
        valid_types = %w[minimize_travel_time minimize_total_cost balance_workload maximize_revenue]
        unless valid_types.include?(optimization_type)
          return {
            optimization_job: nil,
            routes: [],
            estimated_savings: nil,
            errors: [ "Invalid optimization type. Must be one of: #{valid_types.join(', ')}" ]
          }
        end

        # Check if there are appointments to optimize
        appointments = account.appointments
                             .where(scheduled_at: date.beginning_of_day..date.end_of_day)
                             .where(status: [ "scheduled", "confirmed" ])

        if staff_ids.present?
          appointments = appointments.where(staff_id: staff_ids)
        end

        if appointments.empty?
          return {
            optimization_job: nil,
            routes: [],
            estimated_savings: nil,
            errors: [ "No appointments found for optimization on #{date}" ]
          }
        end

        # Async mode: queue job and return immediately
        if async
          return run_async_optimization(account, date, optimization_type, staff_ids)
        end

        # Sync mode: run optimization and wait for result
        optimizer = SimpleRouteOptimizerService.new(
          account_id: account.id,
          date: date,
          optimization_type: optimization_type,
          staff_ids: staff_ids || []
        )

        result = optimizer.optimize!

        if result[:success]
          {
            optimization_job: result[:optimization_job],
            routes: result[:routes],
            estimated_savings: build_savings_object(result[:metrics]),
            errors: []
          }
        else
          {
            optimization_job: result[:optimization_job],
            routes: [],
            estimated_savings: nil,
            errors: [ result[:error] ]
          }
        end

      rescue ActiveRecord::RecordNotFound => e
        {
          optimization_job: nil,
          routes: [],
          estimated_savings: nil,
          errors: [ "Record not found: #{e.message}" ]
        }
      rescue StandardError => e
        Rails.logger.error "Route optimization mutation failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        {
          optimization_job: nil,
          routes: [],
          estimated_savings: nil,
          errors: [ "Optimization failed: #{e.message}" ]
        }
      end
    end

    private

    def extract_savings_from_job(job)
      return nil unless job.result

      OpenStruct.new(
        time_saved_hours: job.result["time_saved_hours"],
        cost_savings: job.result["cost_savings"],
        efficiency_improvement_percent: job.result["efficiency_improvement"],
        total_distance_km: job.result.dig("optimization_metrics", "total_distance_km"),
        routes_created: job.result["routes_created"]
      )
    end

    def build_savings_object(metrics)
      return nil unless metrics

      OpenStruct.new(
        time_saved_hours: metrics["time_saved_hours"],
        cost_savings: metrics["cost_savings"],
        efficiency_improvement_percent: metrics["efficiency_improvement"],
        total_distance_km: metrics["total_distance_km"],
        routes_created: metrics["routes_created"]
      )
    end

    def run_async_optimization(account, date, optimization_type, staff_ids)
      # Create a pending optimization job
      job = OptimizationJob.create!(
        account: account,
        requested_date: date,
        status: "pending",
        parameters: {
          optimization_type: optimization_type,
          staff_ids: staff_ids || []
        }
      )

      # Queue the background job
      RouteOptimizationJob.perform_later(job.id)

      {
        optimization_job: job,
        routes: [],
        estimated_savings: nil,
        errors: []
      }
    end
  end
end
