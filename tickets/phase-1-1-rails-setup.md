# Phase 1, Ticket 1: Initial Rails Application Setup

**Priority**: High  
**Estimated Time**: 2-3 hours  
**Prerequisites**: Ruby 3.x, Rails 7.x installed  

## Objective

Create a new Ruby on Rails application with PostgreSQL database and basic configuration for the Family Photo Share project.

## Acceptance Criteria

- [ ] New Rails 7.x application created with PostgreSQL database
- [ ] Application runs successfully on `localhost:3000`
- [ ] Database connection established and migrations run
- [ ] Git repository initialized with initial commit
- [ ] Basic gems added to Gemfile
- [ ] Development and test environments configured

## Technical Requirements

### 1. Create Rails Application
```bash
rails new . --database=postgresql --skip-action-mailbox --skip-action-text
cd family-photo-share
```

### 2. Update Gemfile
Add these gems to the Gemfile:

```ruby
# Core functionality
gem 'image_processing', '~> 1.2'  # For Active Storage variants

# Authentication (prepare for next phase)
gem 'devise'
gem 'omniauth'
gem 'omniauth-google-oauth2'
gem 'omniauth-rails_csrf_protection'

# Background jobs
gem 'sidekiq'
gem 'redis', '~> 4.0'

# UI enhancements
gem 'turbo-rails'
gem 'stimulus-rails'

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pry-rails'
end

group :development do
  gem 'rubocop-rails', require: false
  gem 'bullet'  # N+1 query detection
end

group :test do
  gem 'shoulda-matchers'
  gem 'capybara'
  gem 'selenium-webdriver'
end
```

### 3. Database Configuration
- Configure `config/database.yml` for development and test environments
- Ensure PostgreSQL service is running
- Create and migrate database

### 4. Basic Configuration
- Set timezone to UTC in `config/application.rb`
- Configure Active Storage for local storage (development)
- Add basic security headers

### 5. Git Setup
- Initialize git repository
- Create `.gitignore` with Rails defaults plus:
  ```
  /config/master.key
  /config/credentials/*.key
  .env
  /storage/*
  !/storage/.keep
  ```

## Testing Requirements

- [ ] `rails server` starts without errors
- [ ] `rails db:create db:migrate` runs successfully
- [ ] `bundle install` completes without issues
- [ ] Rails console (`rails c`) opens successfully
- [ ] Test suite runs (`bundle exec rspec` after setup)

## Files to Create/Modify

- `Gemfile` - Add required gems
- `config/database.yml` - PostgreSQL configuration
- `config/application.rb` - Basic app configuration
- `.gitignore` - Version control exclusions
- `README.md` - Basic project documentation

## Deliverables

1. Working Rails application
2. Successful database connection
3. Git repository with initial commit
4. Updated README with setup instructions
5. Gemfile with all required dependencies

## Notes for Junior Developer

- Make sure PostgreSQL is installed and running on your system
- If you encounter permission issues with PostgreSQL, check your local configuration
- The `--skip-action-mailbox` and `--skip-action-text` flags remove unused Rails components
- Don't worry about styling yet - we'll handle that in later phases
- If bundle install fails, check your Ruby version compatibility

## Validation Steps

1. Start Rails server: `rails server`
2. Visit `http://localhost:3000` - should see Rails welcome page
3. Open Rails console: `rails console`
4. Run: `ActiveRecord::Base.connection` - should connect without error
5. Check git status: `git status` - should show clean working directory

## Next Steps

After completing this ticket, you'll move to Phase 1, Ticket 2: Testing Framework Setup.