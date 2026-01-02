source "https://rubygems.org"

ruby "3.2.0"

# Rails Core
gem "rails", "~> 8.0.0"
gem "bootsnap", require: false
gem "dotenv-rails", groups: %i[development test]

# Database & Persistence
gem "pg", "~> 1.1"
gem "ulid", "~> 1.2.0"
gem "discard", "~> 1.2"
gem "will_paginate", "~> 4.0"

# API & GraphQL
gem "graphql", "~> 2.0"
gem "jbuilder"

# Background Jobs
gem "sidekiq", "~> 7.0"
gem "redis", "> 5"

# Authentication & Authorization
gem "devise", "~> 4.9"
gem "jwt", "~> 2.7"

# Forms & Validation
gem "reform-rails"
gem "reform"

# File Uploads
gem "shrine", "~> 3.0"
gem "image_processing", "~> 1.8"

# Feature Flags
gem "flipper"
gem "flipper-active_record"
gem "flipper-ui"

# Payments (like ZenMaid)
gem "stripe", "~> 5.55"
gem "stripe_event", "~> 2.3"

# Utils & Helpers
gem "money-rails"
gem "chronic", "~> 0.10"
gem "sanitize"
gem "oj"

# HTTP Client
gem "faraday", "~> 2.7"
gem "faraday-retry"

# Scheduling & Calendar
gem "icalendar", "~> 2.4"
gem "ice_cube"

# Decorators
gem "draper"

# Error Tracking
gem "rollbar"

group :development, :test do
  gem "pry-rails"
  gem "pry-byebug"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "timecop"
  gem "brakeman", require: false
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "listen"
  gem "bullet"
  gem "graphiql-rails"
  gem "letter_opener"
  gem "annotate"
  gem "graphiql-rails"
end

group :test do
  gem "capybara"
  gem "database_cleaner-active_record"
  gem "rspec-sidekiq"
  gem "webmock"
  gem "simplecov", require: false
end

group :production do
  gem "puma", "~> 6.0"
  gem "rack-cors"
end
