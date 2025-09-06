FactoryBot.define do
  factory :travel_segment do
    from_appointment { nil }
    to_appointment { nil }
    distance_meters { 1 }
    duration_seconds { 1 }
    traffic_factor { "9.99" }
  end
end
