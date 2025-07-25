# Contributing to Family Photo Share

Thank you for your interest in contributing to Family Photo Share! This document provides guidelines and information for contributors.

## Table of Contents

- [Getting Started](#getting-started)
- [Development Environment](#development-environment)
- [How to Contribute](#how-to-contribute)
- [Code Guidelines](#code-guidelines)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)
- [Community Guidelines](#community-guidelines)

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Ruby 3.4.2
- Docker and Docker Compose (recommended)
- Git
- A GitHub account

### Development Setup

1. **Fork the repository**
   ```bash
   # Fork via GitHub UI, then clone your fork
   git clone https://github.com/yourusername/family-photo-share.git
   cd family-photo-share
   git remote add upstream https://github.com/original/family-photo-share.git
   ```

2. **Set up development environment**
   ```bash
   # Using Docker (recommended)
   cp .env.example .env
   docker-compose up -d
   docker-compose exec web rails db:create db:migrate db:seed
   
   # Or local development
   bundle install
   rails db:create db:migrate db:seed
   ```

3. **Verify setup**
   ```bash
   # Run tests to ensure everything works
   docker-compose exec web rspec
   # or locally: bundle exec rspec
   ```

## Development Environment

### Using Docker (Recommended)

```bash
# Start all services
docker-compose up -d

# Run commands in web container
docker-compose exec web rails console
docker-compose exec web rspec
docker-compose exec web rubocop

# View logs
docker-compose logs -f web
```

### Local Development

```bash
# Install dependencies
bundle install
yarn install

# Start services
rails server               # Terminal 1
bundle exec sidekiq        # Terminal 2
redis-server              # Terminal 3 (if not already running)
```

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

- **Bug fixes**: Help us squash bugs
- **Feature development**: Add new functionality
- **Documentation**: Improve docs and guides
- **Testing**: Add or improve test coverage
- **Performance**: Optimize existing code
- **UI/UX**: Enhance user experience

### Contribution Workflow

1. **Check existing issues** - Look for existing issues or create a new one
2. **Discuss the change** - For major features, discuss in an issue first
3. **Create a branch** - Use descriptive branch names
4. **Make changes** - Follow our coding standards
5. **Add tests** - Ensure new code has appropriate test coverage
6. **Update documentation** - Update relevant docs
7. **Submit PR** - Create a pull request with clear description

### Branch Naming

Use descriptive branch names:

```bash
git checkout -b feature/album-sorting
git checkout -b fix/photo-upload-error
git checkout -b docs/api-documentation
git checkout -b refactor/photo-processing
```

## Code Guidelines

### Ruby Style Guide

We follow the Ruby Style Guide with some modifications:

- Use 2 spaces for indentation
- Keep lines under 120 characters
- Use descriptive method and variable names
- Follow Rails conventions

### Code Formatting

We use RuboCop to enforce style:

```bash
# Check for style violations
docker-compose exec web rubocop

# Auto-fix simple issues
docker-compose exec web rubocop -a

# Check specific files
docker-compose exec web rubocop app/models/photo.rb
```

### Commit Messages

Write clear, descriptive commit messages:

```bash
# Good
git commit -m "Add EXIF data extraction for uploaded photos"
git commit -m "Fix album cover photo not updating properly"
git commit -m "Refactor photo processing job for better error handling"

# Avoid
git commit -m "fix bug"
git commit -m "changes"
git commit -m "wip"
```

#### Commit Message Format

```
type(scope): short description

Longer description if needed

- List any breaking changes
- Reference issues: Fixes #123
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Code style (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

### Code Documentation

#### Method Documentation

Document public methods, especially complex ones:

```ruby
# Extracts EXIF metadata from uploaded photo
#
# @param photo [Photo] The photo to process
# @return [Hash] Extracted metadata hash
# @raise [ExifError] When EXIF extraction fails
def extract_metadata(photo)
  # Implementation
end
```

#### Model Documentation

Document model relationships and key methods:

```ruby
class Photo < ApplicationRecord
  # A photo uploaded by a user that can belong to multiple albums
  # Stores EXIF metadata and generates various image variants
  
  belongs_to :user
  has_and_belongs_to_many :albums
  
  # Validates that uploaded file is a supported image format
  validates :image, presence: true, content_type: SUPPORTED_FORMATS
end
```

## Testing

### Test Requirements

All contributions must include appropriate tests:

- **Models**: Test validations, associations, and custom methods
- **Controllers**: Test request/response cycles and authorization
- **Jobs**: Test background job execution and error handling
- **Features**: Test critical user workflows end-to-end

### Running Tests

```bash
# Run all tests
docker-compose exec web rspec

# Run specific test files
docker-compose exec web rspec spec/models/photo_spec.rb
docker-compose exec web rspec spec/features/photo_upload_spec.rb

# Run with coverage
docker-compose exec web COVERAGE=true rspec

# Run specific test types
docker-compose exec web rspec spec/models/
docker-compose exec web rspec spec/controllers/
docker-compose exec web rspec spec/features/
```

### Writing Tests

#### Model Tests

```ruby
RSpec.describe Photo, type: :model do
  describe 'validations' do
    it 'requires an image to be attached' do
      photo = build(:photo)
      expect(photo).to be_invalid
      expect(photo.errors[:image]).to include("can't be blank")
    end
  end
  
  describe '#extract_exif_data' do
    it 'extracts date taken from EXIF data' do
      photo = create(:photo, :with_exif_data)
      expect(photo.taken_at).to be_present
    end
  end
end
```

#### Controller Tests

```ruby
RSpec.describe PhotosController, type: :controller do
  let(:user) { create(:user) }
  
  before { sign_in user }
  
  describe 'POST #create' do
    it 'creates a new photo' do
      expect {
        post :create, params: { photo: { image: fixture_file_upload('test.jpg') } }
      }.to change(Photo, :count).by(1)
    end
  end
end
```

#### Feature Tests

```ruby
RSpec.describe 'Photo Upload', type: :feature do
  let(:user) { create(:user) }
  
  before { sign_in user }
  
  it 'allows user to upload a photo' do
    visit new_photo_path
    attach_file 'Image', Rails.root.join('spec/fixtures/test.jpg')
    click_button 'Upload Photo'
    
    expect(page).to have_content('Photo uploaded successfully')
    expect(Photo.count).to eq(1)
  end
end
```

### Test Data

Use FactoryBot for test data:

```ruby
FactoryBot.define do
  factory :photo do
    user
    title { "Test Photo" }
    
    trait :with_image do
      after(:build) do |photo|
        photo.image.attach(
          io: File.open('spec/fixtures/test.jpg'),
          filename: 'test.jpg',
          content_type: 'image/jpeg'
        )
      end
    end
  end
end
```

## Pull Request Process

### Before Submitting

1. **Update your branch**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests**
   ```bash
   docker-compose exec web rspec
   ```

3. **Check code style**
   ```bash
   docker-compose exec web rubocop
   ```

4. **Update documentation** if needed

### PR Requirements

Your pull request must:

- [ ] Pass all existing tests
- [ ] Include tests for new functionality
- [ ] Follow code style guidelines
- [ ] Include clear description of changes
- [ ] Reference related issues
- [ ] Update relevant documentation

### PR Description Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] Added tests for new functionality
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review of code completed
- [ ] Comments added to complex code
- [ ] Documentation updated
- [ ] No new warnings introduced

## Screenshots (if applicable)
Add screenshots for UI changes.

## Related Issues
Fixes #123
```

### Review Process

1. **Automated checks** - GitHub Actions will run tests
2. **Code review** - Maintainers will review your code
3. **Feedback** - Address any requested changes
4. **Approval** - Once approved, your PR will be merged

## Issue Reporting

### Bug Reports

When reporting bugs, include:

- **Environment** (OS, Ruby version, browser)
- **Steps to reproduce** the issue
- **Expected behavior**
- **Actual behavior**
- **Screenshots** (if applicable)
- **Error messages** (full stack traces)

### Feature Requests

For feature requests, include:

- **Problem description** - What problem does this solve?
- **Proposed solution** - How should it work?
- **Alternatives considered** - Other approaches?
- **Additional context** - Screenshots, mockups, etc.

### Issue Labels

We use labels to categorize issues:

- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Documentation improvements
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed
- `priority:high` - High priority issues
- `priority:low` - Low priority issues

## Community Guidelines

### Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

### Communication

- **Be respectful** in all interactions
- **Be constructive** in feedback and criticism
- **Be collaborative** when working together
- **Be patient** with new contributors

### Getting Help

If you need help:

1. Check the [documentation](docs/)
2. Search existing [issues](https://github.com/yourusername/family-photo-share/issues)
3. Ask in [discussions](https://github.com/yourusername/family-photo-share/discussions)
4. Join our [Discord/Slack] (if available)

## Development Tips

### Debugging

```bash
# View application logs
docker-compose logs -f web

# Access Rails console
docker-compose exec web rails console

# Debug Sidekiq jobs
docker-compose logs -f sidekiq

# Check database
docker-compose exec postgres psql -U postgres -d family_photo_share_development
```

### Performance

- Use database indexes appropriately
- Optimize N+1 queries with `includes`
- Use background jobs for heavy operations
- Profile with tools like `bullet` gem

### Security

- Never commit secrets or credentials
- Validate and sanitize user input
- Use parameterized queries
- Follow Rails security best practices

## Recognition

Contributors are recognized in:

- CHANGELOG.md
- Contributors section
- Release notes
- Special thanks in documentation

Thank you for contributing to Family Photo Share! 🎉

---

For questions about contributing, please open an issue or reach out to the maintainers.