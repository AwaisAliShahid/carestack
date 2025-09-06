class RouteStop < ApplicationRecord
  belongs_to :route
  belongs_to :appointment

  validates :stop_order, presence: true, uniqueness: { scope: :route_id }
  validates :estimated_arrival, presence: true

  scope :ordered, -> { order(:stop_order) }

  def duration_at_stop
    return 0 if estimated_departure.blank? || estimated_arrival.blank?
    
    estimated_departure - estimated_arrival
  end

  def service_duration
    appointment.service_type.duration_minutes * 60
  end

  def buffer_time
    duration_at_stop - service_duration
  end

  def on_time?
    return nil if actual_arrival.blank? || estimated_arrival.blank?
    
    (actual_arrival - estimated_arrival).abs < 15.minutes
  end

  def delayed?
    return false if actual_arrival.blank? || estimated_arrival.blank?
    
    actual_arrival > estimated_arrival + 15.minutes
  end

  def delay_minutes
    return 0 if actual_arrival.blank? || estimated_arrival.blank?
    
    [(actual_arrival - estimated_arrival) / 60, 0].max.round
  end
end