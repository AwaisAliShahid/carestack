class OptimizationJob < ApplicationRecord
  belongs_to :account

  validates :requested_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }

  scope :recent, -> { where(created_at: 1.week.ago..) }
  scope :for_date, ->(date) { where(requested_date: date) }

  def processing_time_seconds
    return nil unless processing_started_at && processing_completed_at

    processing_completed_at - processing_started_at
  end

  def success?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def processing?
    status == "processing"
  end

  def time_savings
    return nil unless success? && result&.dig("time_saved_hours")

    result["time_saved_hours"]
  end

  def cost_savings
    return nil unless success? && result&.dig("cost_savings")

    result["cost_savings"]
  end

  def routes_created
    return 0 unless success? && result&.dig("routes_created")

    result["routes_created"]
  end
end
