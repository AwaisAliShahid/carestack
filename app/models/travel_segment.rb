class TravelSegment < ApplicationRecord
  belongs_to :from_appointment
  belongs_to :to_appointment
end
