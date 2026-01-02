# CareStack

A multi-vertical service management platform built with Ruby on Rails 8, designed for home service businesses (cleaning, elderly care, tutoring, home repair).

## Features

- **Multi-Vertical Support**: Configurable for different service industries with vertical-specific compliance requirements
- **Route Optimization**: Intelligent scheduling using nearest-neighbor algorithm with optional Google Maps Distance Matrix API integration
- **GraphQL API**: Modern API layer for flexible client integrations
- **Appointment Management**: Full lifecycle management for service appointments
- **Staff Management**: Track staff availability, skills, certifications, and home locations

## Tech Stack

- **Ruby**: 3.2.0
- **Rails**: 8.0.0
- **Database**: PostgreSQL
- **API**: GraphQL (graphql-ruby 2.0)
- **Background Jobs**: Sidekiq 7.0
- **Testing**: RSpec with FactoryBot

## Architecture

```
app/
├── graphql/           # GraphQL schema, types, and mutations
│   ├── mutations/     # CreateAppointment, OptimizeRoutes, etc.
│   └── types/         # GraphQL type definitions
├── models/            # ActiveRecord models
│   ├── account.rb     # Multi-tenant account model
│   ├── appointment.rb # Core appointment scheduling
│   ├── customer.rb    # Customer management
│   ├── route.rb       # Optimized route storage
│   ├── staff.rb       # Staff/technician management
│   └── vertical.rb    # Industry vertical configuration
└── services/          # Business logic services
    ├── google_maps_service.rb          # Real Google Maps API integration
    ├── mock_google_maps_service.rb     # Mock for development/testing
    └── simple_route_optimizer_service.rb  # Route optimization logic
```

## Getting Started

### Prerequisites

- Ruby 3.2.0
- PostgreSQL 14+
- Redis (for Sidekiq)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd carestack

# Install dependencies
bundle install

# Setup environment
cp .env.sample .env
# Edit .env with your configuration

# Setup database
rails db:create db:migrate

# Run tests
bundle exec rspec
```

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `DATABASE_URL` | PostgreSQL connection string | Yes |
| `REDIS_URL` | Redis connection for Sidekiq | Yes |
| `GOOGLE_MAPS_API_KEY` | Google Maps API key for route optimization | No* |
| `STRIPE_API_KEY` | Stripe API key for payments | No |
| `ROLLBAR_ACCESS_TOKEN` | Error tracking | No |

*Without a Google Maps API key, the system uses a mock service with realistic Edmonton-area coordinates for development.

### Google Maps API Setup

For production route optimization:

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new API key
3. Enable the following APIs:
   - Geocoding API
   - Distance Matrix API
   - Directions API
4. Add the key to your environment: `GOOGLE_MAPS_API_KEY=your_key_here`

## Testing

```bash
# Run all tests
bundle exec rspec

# Run with coverage report
COVERAGE=true bundle exec rspec

# Run specific test file
bundle exec rspec spec/services/simple_route_optimizer_service_spec.rb
```

## API Usage

### GraphQL Endpoint

`POST /graphql`

### Example: Create Appointment

```graphql
mutation CreateAppointment {
  createAppointment(
    accountId: "1"
    customerId: "1"
    serviceTypeId: "1"
    staffId: "1"
    scheduledAt: "2025-01-15T09:00:00Z"
    duration: 60
  ) {
    appointment {
      id
      status
      scheduledAt
    }
    errors
  }
}
```

### Example: Optimize Routes

```graphql
mutation OptimizeRoutes {
  optimizeRoutes(
    accountId: "1"
    date: "2025-01-15"
    optimizationType: "minimize_travel_time"
  ) {
    routes {
      id
      totalDistanceMeters
      totalDurationSeconds
    }
    estimatedSavings {
      timeSavedHours
      costSavings
      efficiencyImprovementPercent
    }
    errors
  }
}
```

## Route Optimization

The system supports multiple optimization strategies:

- `minimize_travel_time` - Reduce total driving time (default)
- `minimize_total_cost` - Optimize for fuel and labor costs
- `balance_workload` - Distribute appointments evenly across staff
- `maximize_revenue` - Prioritize high-value appointments

### Algorithm

Currently implements a **nearest-neighbor heuristic**:
1. Start from each staff member's home location
2. Visit the closest unvisited appointment
3. Repeat until all appointments are scheduled
4. Return to home location

A genetic algorithm solver (`GeneticVrpSolver`) is available for more advanced optimization.

## License

MIT
