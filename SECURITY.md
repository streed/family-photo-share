# Security Policy

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security vulnerability, please follow these steps:

### Private Disclosure

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please use GitHub's private vulnerability reporting feature:

1. Go to the Security tab in the repository
2. Click on "Report a vulnerability"
3. Follow the private disclosure process

You should receive a response within 48 hours.

### What to Include

When reporting a vulnerability, please include:

* A description of the vulnerability
* Steps to reproduce the issue
* Affected versions
* Any potential impact
* Suggested fixes (if available)

### Response Process

1. **Acknowledgment**: We'll acknowledge receipt of your vulnerability report within 48 hours
2. **Investigation**: We'll investigate and validate the reported vulnerability
3. **Fix Development**: We'll develop and test a fix for confirmed vulnerabilities
4. **Coordinated Disclosure**: We'll work with you to coordinate public disclosure after a fix is available

### Security Best Practices

Family Photo Share implements several security measures:

* **Authentication**: Devise-based authentication with secure defaults
* **Authorization**: Role-based access control for family groups
* **File Upload Security**: File type validation and size limits
* **CSRF Protection**: Enabled by default in Rails
* **SQL Injection Prevention**: Using parameterized queries
* **Session Security**: Secure session configuration
* **Rate Limiting**: Protection against brute force attacks

### Deployment Security

For production deployments, ensure:

* Use HTTPS/TLS encryption
* Keep dependencies updated
* Use strong passwords and secrets
* Configure firewall rules appropriately
* Regular security updates and monitoring
* Backup encryption and secure storage

## Acknowledgments

We appreciate the security research community and will acknowledge security researchers who help improve our security posture.