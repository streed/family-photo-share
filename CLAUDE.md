# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Family Photo Share is a Ruby on Rails application that allows families to share photos privately. Users can create accounts, upload photos to albums, invite family members, and manage access with role-based permissions.

## Tech Stack

- **Backend**: Ruby on Rails 7.x
- **Database**: PostgreSQL
- **File Storage**: Active Storage (for photo uploads)
- **Background Jobs**: Sidekiq with Redis
- **Authentication**: Devise + OmniAuth (Google OAuth)
- **Frontend**: ERB templates with JavaScript for dynamic features
- **Styling**: CSS/SCSS (framework TBD)

## Key Features

- Google OAuth and email/password authentication
- Photo upload and storage with Active Storage
- Album creation and management
- Family invitation system with role-based access (owner/editor/viewer)
- Temporary album sharing with passcodes
- Role-based permissions for family members

## Development Commands

```bash
# Setup (after initial Rails generation)
bundle install
rails db:create db:migrate
redis-server  # For Sidekiq
bundle exec sidekiq  # Background jobs

# Development server
rails server

# Testing
bundle exec rspec
bundle exec rubocop  # Code linting

# Database
rails db:migrate
rails db:seed
rails db:rollback
```

## Project Structure

- `tickets/` - Development tickets organized by phases
- Standard Rails app structure with MVC pattern
- Background jobs in `app/jobs/`
- Mailers in `app/mailers/`
- Role management in `app/models/concerns/`

## Development Process

Follow the tickets in the `tickets/` folder, organized by development phases. Each ticket includes acceptance criteria, technical requirements, and testing guidelines.