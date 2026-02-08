source "https://rubygems.org"

ruby "3.2.0"

# Rails Core
gem "rails", "~> 8.0.0"
gem "bootsnap", require: false
gem "puma", "~> 6.0"
gem "dotenv-rails", groups: %i[development test]

# Database & Persistence
gem "pg", "~> 1.1"

# API & GraphQL
gem "graphql", "~> 2.0"
gem "rack-cors"

# Background Jobs
gem "sidekiq", "~> 7.0"
gem "redis", "> 5"

# Authentication & Authorization
gem "devise", "~> 4.9"
gem "jwt", "~> 2.7"

# JSON
gem "oj"

# HTTP Client
gem "faraday", "~> 2.7"
gem "faraday-retry"

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
end

group :test do
  gem "database_cleaner-active_record"
  gem "rspec-sidekiq"
  gem "webmock"
  gem "simplecov", require: false
end
