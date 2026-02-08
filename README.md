# CareStack

A multi-vertical service management platform built with Ruby on Rails 8, designed for home service businesses (cleaning, elderly care, tutoring, home repair).

## Features

- **Multi-Vertical Support**: Configurable for different service industries with vertical-specific compliance requirements
- **Route Optimization**: Nearest-neighbor heuristic and genetic algorithm (VRP solver) for intelligent scheduling
- **GraphQL API**: Modern API layer with authentication, authorization, and dataloader for N+1 prevention
- **Appointment Management**: Full lifecycle management with vertical-specific business rules
- **Staff Management**: Track staff availability, skills, certifications, and home locations
- **Background Jobs**: Async route optimization via Sidekiq

## Tech Stack

- **Ruby**: 3.3.0
- **Rails**: 8.0.0
- **Database**: PostgreSQL
- **API**: GraphQL (graphql-ruby 2.0)
- **Background Jobs**: Sidekiq 7.0
- **Authentication**: Devise + JWT
- **Testing**: RSpec with FactoryBot (499 tests, 85%+ coverage)

## Architecture

```
app/
├── graphql/
│   ├── concerns/      # Authorize module (auth layer)
│   ├── mutations/     # CreateAppointment, OptimizeRoutes
│   ├── sources/       # GraphQL Dataloader sources (N+1 prevention)
│   └── types/         # GraphQL type definitions
├── models/
│   ├── account.rb     # Multi-tenant account model
│   ├── appointment.rb # Core appointment scheduling
│   ├── customer.rb    # Customer management
│   ├── route.rb       # Optimized route storage
│   ├── staff.rb       # Staff/technician management
│   ├── user.rb        # Authentication (Devise + JWT)
│   └── vertical.rb    # Industry vertical configuration
├── jobs/
│   └── route_optimization_job.rb  # Async optimization via Sidekiq
└── services/
    ├── genetic_vrp_solver.rb          # Genetic algorithm VRP solver
    ├── google_maps_service.rb         # Real Google Maps API integration
    ├── mock_google_maps_service.rb    # Mock for development/testing
    └── simple_route_optimizer_service.rb  # Route optimization orchestrator
```

## Getting Started

### Prerequisites

- Ruby 3.2.0
- PostgreSQL 14+
- Redis (for Sidekiq)

### Installation

```bash
git clone <repository-url>
cd carestack

bundle install
rails db:create db:migrate db:seed
bundle exec rspec
```

### Demo Credentials

After running `db:seed`:

| Email | Role | Account |
|-------|------|---------|
| `admin@carestack.demo` | Super Admin | All accounts |
| `manager@cleaning.demo` | Manager | Sparkle Clean Edmonton |
| `manager@elderly_care.demo` | Manager | Golden Years Home Care |

Password: `password123`

## API Usage

### GraphQL Endpoint

`POST /graphql`

### Example: Create Appointment

```graphql
mutation {
  createAppointment(input: {
    accountId: "1"
    customerId: "1"
    serviceTypeId: "1"
    staffId: "1"
    scheduledAt: "2026-01-15T09:00:00Z"
  }) {
    appointment {
      id
      status
      scheduledAt
    }
    errors
  }
}
```

### Example: Optimize Routes (Nearest Neighbor)

```graphql
mutation {
  optimizeRoutes(input: {
    accountId: "1"
    date: "2026-01-15"
  }) {
    routes {
      id
      totalDistanceKm
      totalDurationHours
    }
    estimatedSavings {
      timeSavedHours
      costSavings
    }
    errors
  }
}
```

### Example: Optimize Routes (Genetic Algorithm)

```graphql
mutation {
  optimizeRoutes(input: {
    accountId: "1"
    date: "2026-01-15"
    algorithm: "genetic"
    optimizationType: "balance_workload"
  }) {
    routes {
      id
      totalDistanceKm
      totalDurationHours
      routeStops {
        stopOrder
        appointment { customer { firstName lastName } }
      }
    }
    errors
  }
}
```

## Route Optimization

### Algorithms

- **Nearest Neighbor** (`nearest_neighbor`) - Fast greedy heuristic. Good for small datasets.
- **Genetic Algorithm** (`genetic`) - Population-based VRP solver with crossover, mutation, and 2-opt local search. Redistributes appointments across staff for globally optimal routes.

### Optimization Types

- `minimize_travel_time` - Reduce total driving time (default)
- `minimize_total_cost` - Optimize for fuel and labor costs
- `balance_workload` - Distribute appointments evenly across staff
- `maximize_revenue` - Prioritize high-value appointments

## Testing

```bash
bundle exec rspec                    # Run all tests
bundle exec rubocop                  # Lint
bundle exec brakeman -q              # Security scan
```

## License

MIT
