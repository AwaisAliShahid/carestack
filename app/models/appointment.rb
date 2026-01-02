class Appointment < ApplicationRecord
  # Valid status values
  STATUSES = %w[scheduled confirmed in_progress completed cancelled no_show].freeze

  # Relationships
  belongs_to :account
  belongs_to :customer
  belongs_to :service_type
  belongs_to :staff

  # Validations
  validates :scheduled_at, presence: true
  validates :duration_minutes, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # Scopes
  scope :scheduled, -> { where(status: "scheduled") }
  scope :confirmed, -> { where(status: "confirmed") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :active, -> { where(status: %w[scheduled confirmed in_progress]) }
  scope :for_date, ->(date) { where(scheduled_at: date.beginning_of_day..date.end_of_day) }
  scope :upcoming, -> { where("scheduled_at > ?", Time.current).order(:scheduled_at) }
  scope :past, -> { where("scheduled_at < ?", Time.current).order(scheduled_at: :desc) }

  # Instance methods
  def scheduled_end_at
    scheduled_at + duration_minutes.minutes
  end

  def active?
    %w[scheduled confirmed in_progress].include?(status)
  end

  def can_cancel?
    %w[scheduled confirmed].include?(status)
  end

  def can_start?
    status == "confirmed"
  end

  def can_complete?
    status == "in_progress"
  end

  def duration_in_hours
    duration_minutes / 60.0
  end
end
