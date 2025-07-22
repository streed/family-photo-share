# Contributing to Family Photo Share

Thank you for considering contributing to Family Photo Share! We welcome contributions from everyone.

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* Use a clear and descriptive title
* Describe the exact steps to reproduce the problem
* Provide specific examples to demonstrate the steps
* Describe the behavior you observed after following the steps
* Explain which behavior you expected to see instead and why
* Include screenshots if possible

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* Use a clear and descriptive title
* Provide a step-by-step description of the suggested enhancement
* Provide specific examples to demonstrate the steps
* Describe the current behavior and explain which behavior you expected to see instead
* Explain why this enhancement would be useful

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes (`bundle exec rspec`)
5. Make sure your code lints (`bundle exec rubocop`)
6. Issue that pull request!

## Development Process

1. **Setup your development environment**
   ```bash
   cp .env.example .env
   docker-compose up -d
   bundle install
   rails db:setup
   ```

2. **Make your changes**
   - Write clean, maintainable code
   - Follow Ruby style guidelines
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**
   ```bash
   bundle exec rspec
   bundle exec rubocop
   ```

4. **Commit your changes**
   - Use clear and meaningful commit messages
   - Reference issues and pull requests liberally

## Code Style

* Follow the Ruby Style Guide
* Use 2 spaces for indentation
* Keep lines under 120 characters
* Write descriptive variable and method names
* Add comments for complex logic
* Use meaningful commit messages

## Testing

* Write RSpec tests for all new functionality
* Aim for good test coverage
* Test both happy paths and edge cases
* Keep tests focused and readable

## Documentation

* Update the README.md if you change functionality
* Document new environment variables
* Add inline comments for complex code
* Update API documentation if applicable

## Community

* Be respectful and inclusive
* Welcome newcomers and help them get started
* Provide constructive feedback
* Focus on what is best for the community

Thank you for contributing! 🎉