class TravelSegment < ApplicationRecord
  validates :distance_meters, presence: true, numericality: { greater_than: 0 }
  validates :duration_seconds, presence: true, numericality: { greater_than: 0 }
  validates :traffic_factor, numericality: { greater_than: 0 }, allow_nil: true

  def distance_km
    distance_meters / 1000.0
  end

  def duration_minutes
    duration_seconds / 60.0
  end
end
