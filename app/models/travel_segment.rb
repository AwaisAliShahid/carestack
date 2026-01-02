# frozen_string_literal: true

class TravelSegment < ApplicationRecord
  # Relationships
  belongs_to :from_appointment, class_name: "Appointment"
  belongs_to :to_appointment, class_name: "Appointment"

  # Validations
  validates :distance_meters, presence: true, numericality: { greater_than: 0 }
  validates :duration_seconds, presence: true, numericality: { greater_than: 0 }
  validates :traffic_factor, numericality: { greater_than: 0 }, allow_nil: true

  # Computed values
  def distance_km
    distance_meters / 1000.0
  end

  def duration_minutes
    duration_seconds / 60.0
  end

  def duration_with_traffic
    return duration_seconds unless traffic_factor

    (duration_seconds * traffic_factor).to_i
  end
end
