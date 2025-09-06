FactoryBot.define do
  factory :route_stop do
    route { nil }
    appointment { nil }
    stop_order { 1 }
    estimated_arrival { "2025-09-04 12:55:32" }
    estimated_departure { "2025-09-04 12:55:32" }
    actual_arrival { "2025-09-04 12:55:32" }
    actual_departure { "2025-09-04 12:55:32" }
  end
end
