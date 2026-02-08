# frozen_string_literal: true

class RouteOptimizationJob < ApplicationJob
  queue_as :default

  # Retry on transient failures with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  # Don't retry if the account no longer exists
  discard_on ActiveRecord::RecordNotFound

  def perform(optimization_job_id)
    optimization_job = OptimizationJob.find(optimization_job_id)

    # Skip if already completed or failed
    return if %w[completed failed].include?(optimization_job.status)

    begin
      # Run the optimization with the existing job
      optimizer = SimpleRouteOptimizerService.new(
        account_id: optimization_job.account_id,
        date: optimization_job.requested_date,
        optimization_type: optimization_job.parameters["optimization_type"] || "minimize_travel_time",
        algorithm: optimization_job.parameters["algorithm"] || "nearest_neighbor",
        staff_ids: optimization_job.parameters["staff_ids"] || [],
        optimization_job: optimization_job
      )

      result = optimizer.optimize!

      if result[:success]
        # Job already updated by the service, but let's ensure completion
        optimization_job.reload
        Rails.logger.info "Route optimization job #{optimization_job_id} completed successfully"
      else
        optimization_job.update!(
          status: "failed",
          processing_completed_at: Time.current,
          result: { error: result[:error] }
        )
        Rails.logger.error "Route optimization job #{optimization_job_id} failed: #{result[:error]}"
      end

    rescue StandardError => e
      optimization_job.update!(
        status: "failed",
        processing_completed_at: Time.current,
        result: { error: e.message, backtrace: e.backtrace.first(5) }
      )
      Rails.logger.error "Route optimization job #{optimization_job_id} exception: #{e.message}"
      raise # Re-raise to trigger retry logic
    end
  end
end
