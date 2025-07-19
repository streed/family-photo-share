# Phase 1, Ticket 3: Development Tools Setup

**Priority**: Medium  
**Estimated Time**: 1 hour  
**Prerequisites**: Completed Phase 1, Ticket 2  

## Objective

Configure development tools including code linting, debugging tools, and performance monitoring for a smooth development experience.

## Acceptance Criteria

- [ ] Rubocop configured with Rails-friendly rules
- [ ] Bullet gem configured for N+1 query detection
- [ ] Pry-rails set up for better debugging
- [ ] Redis configured for Sidekiq (future background jobs)
- [ ] Basic performance monitoring in place
- [ ] Development-specific configurations added

## Technical Requirements

### 1. Configure Rubocop
Create `.rubocop.yml`:
```yaml
require:
  - rubocop-rails

AllCops:
  TargetRubyVersion: 3.0
  NewCops: enable
  Exclude:
    - 'bin/**/*'
    - 'config/**/*'
    - 'db/**/*'
    - 'vendor/**/*'
    - 'node_modules/**/*'
    - 'tmp/**/*'
    - 'log/**/*'
    - 'storage/**/*'

# Rails-specific cops
Rails:
  Enabled: true

# Adjust some rules for better Rails development
Style/Documentation:
  Enabled: false

Style/FrozenStringLiteralComment:
  Enabled: false

Layout/LineLength:
  Max: 120

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'
    - 'config/routes.rb'

Style/ClassAndModuleChildren:
  Enabled: false
```

### 2. Configure Bullet (N+1 Detection)
Add to `config/environments/development.rb`:
```ruby
# Bullet configuration for N+1 query detection
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true
end
```

### 3. Configure Redis for Sidekiq
Create `config/initializers/redis.rb`:
```ruby
# Redis configuration for Sidekiq and caching
redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')

Redis.current = Redis.new(url: redis_url)
```

Add to `config/environments/development.rb`:
```ruby
# Use Redis for caching in development
config.cache_store = :redis_cache_store, { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
```

### 4. Configure Sidekiq
Create `config/initializers/sidekiq.rb`:
```ruby
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end
```

Add to `config/routes.rb`:
```ruby
# Mount Sidekiq web UI in development
Rails.application.routes.draw do
  if Rails.env.development?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
  
  # Other routes will go here
end
```

### 5. Environment Variables Setup
Create `.env.example`:
```bash
# Database
DATABASE_URL=postgresql://username:password@localhost/family_photo_share_development

# Redis
REDIS_URL=redis://localhost:6379/0

# Future OAuth credentials (Phase 2)
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Rails
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
```

Add to `.gitignore`:
```
.env
.env.local
```

### 6. Configure Pry for Better Debugging
The gem is already in the Gemfile from Phase 1. Create `.pryrc`:
```ruby
# .pryrc - Pry configuration
if defined?(PryRails::RAILS_PROMPT)
  Pry.config.prompt = PryRails::RAILS_PROMPT
end

# Useful aliases
Pry.config.commands.alias_command 'c', 'continue'
Pry.config.commands.alias_command 's', 'step'
Pry.config.commands.alias_command 'n', 'next'
Pry.config.commands.alias_command 'f', 'finish'

# Better output formatting
Pry.config.print = proc do |output, value|
  Pry::Helpers::BaseHelpers.stagger_output("=> #{value.ai}", output)
end
```

### 7. Add Development Scripts
Create `bin/dev`:
```bash
#!/usr/bin/env bash

# Development startup script
echo "Starting Family Photo Share development environment..."

# Check if Redis is running
if ! pgrep -x "redis-server" > /dev/null; then
  echo "Starting Redis..."
  redis-server --daemonize yes
fi

# Start Rails server
echo "Starting Rails server..."
rails server
```

Make it executable:
```bash
chmod +x bin/dev
```

## Testing Requirements

- [ ] `rubocop` runs without major violations
- [ ] Redis connection works: `Rails.cache.write('test', 'value')` in console
- [ ] Bullet detects N+1 queries when they occur
- [ ] Pry opens properly when `binding.pry` is used
- [ ] Sidekiq web interface accessible at `/sidekiq`

## Files to Create/Modify

- `.rubocop.yml` - Rubocop configuration
- `config/environments/development.rb` - Development environment settings
- `config/initializers/redis.rb` - Redis configuration
- `config/initializers/sidekiq.rb` - Sidekiq configuration
- `config/routes.rb` - Add Sidekiq web mount
- `.env.example` - Environment variables template
- `.pryrc` - Pry configuration
- `bin/dev` - Development startup script

## Deliverables

1. Properly configured code linting with Rubocop
2. N+1 query detection with Bullet
3. Redis and Sidekiq ready for background jobs
4. Enhanced debugging with Pry
5. Development startup script

## Notes for Junior Developer

- Rubocop helps maintain consistent code style across the team
- Bullet will help you catch performance issues early
- Redis is required for Sidekiq background jobs we'll add later
- Pry is much more powerful than IRB for debugging
- The `bin/dev` script simplifies starting the development environment

## Validation Steps

1. Run linter: `bundle exec rubocop`
2. Start Redis: `redis-server` (or check if running)
3. Test Redis connection in Rails console: `Rails.cache.write('test', 'working')`
4. Visit Sidekiq web UI: `http://localhost:3000/sidekiq`
5. Test Pry: Add `binding.pry` to any controller and verify it stops execution

## Common Issues and Solutions

- **Redis connection refused**: Make sure Redis server is installed and running
- **Rubocop too strict**: The configuration is already relaxed for Rails development
- **Sidekiq web not accessible**: Check that routes are properly configured

## Next Steps

After completing this ticket, you'll move to Phase 2: Authentication & User Management, starting with basic user models.