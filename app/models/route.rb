class Route < ApplicationRecord
  belongs_to :account
  belongs_to :staff, optional: true
  belongs_to :optimization_job, optional: true
  has_many :route_stops, dependent: :destroy
  has_many :appointments, through: :route_stops

  validates :scheduled_date, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending optimized active completed cancelled] }

  scope :for_date, ->(date) { where(scheduled_date: date) }
  scope :active, -> { where(status: %w[optimized active]) }

  def total_distance_km
    (total_distance_meters || 0) / 1000.0
  end

  def total_duration_hours
    (total_duration_seconds || 0) / 3600.0
  end

  def estimated_fuel_cost(cost_per_km = 0.15)
    total_distance_km * cost_per_km
  end

  def staff_member
    # Use direct staff_id if set, otherwise fall back to looking through stops
    staff || route_stops.joins(:appointment).first&.appointment&.staff
  end
end
