# Changelog

All notable changes to Family Photo Share will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Invitation-Only Registration**: Creating an account now requires a family invitation.
  Open sign-up is off unless `ALLOW_PUBLIC_SIGNUP` is set, and the sign-up links disappear
  from the landing and auth pages while it is off
- **Collaborative Albums**: A family album can be opened up (`allow_contributions`) so every
  member of the owner's family adds their own photos to it. Contributors add and remove their
  own photos — from the album page or by bulk upload — while the album's name, cover, link
  sharing, guest analytics and deletion stay with the owner
- **EXIF Data Processing**: Automatic extraction of photo metadata including date taken, GPS coordinates, and camera information
- **Bulk EXIF Updates**: Rake tasks for processing existing photos (`photos:update_exif_direct`, `photos:exif_stats`)
- **Smart Album Sorting**: Albums now sort photos by date taken (extracted from EXIF) with fallback to creation date
- **External Album Sharing**: Password-protected album sharing with guest session management
- **Guest Session Tracking**: Monitor and manage external access to shared albums
- **QR Code Generation**: Easy sharing via QR codes for external albums
- **Slideshow Mode**: Full-screen photo viewing with navigation
- **Professional Documentation**: Comprehensive README, CONTRIBUTING guide, and API documentation
- **Docker Development Environment**: Full Docker Compose setup for development and production
- **Background Job Management**: Multiple Sidekiq queues for different processing types
- **Rate Limiting**: Protection against brute force login attempts with progressive lockouts
- **Storage Management**: Tasks for cleaning up orphaned files and expired sessions
- **Comprehensive Testing**: RSpec test suite with factories and system tests

### Changed
- **Newest First**: Albums, the public shared-album page and the add-photo picker all lead with
  the most recent photo instead of the oldest. Album ordering stays position-based (so photos
  don't move around when EXIF dates are backfilled) — only the direction changed
- **Paginated Album Grids**: An album's photos now page 24 at a time, and the add-photo picker
  pages 20 at a time instead of showing the first 20 and a dead-end link to the photo library
- **Photo Sorting**: Albums now display photos sorted by date taken instead of manual position
- **Authentication**: Enhanced login error handling with attempt tracking
- **Image Processing**: Improved EXIF extraction with better error handling
- **User Interface**: Enhanced photo grid layout with better responsive design
- **Documentation**: Complete rewrite of README with professional structure
- **Development Workflow**: Added comprehensive contributing guidelines

### Fixed
- **Public Album N+1**: the shared-album page resolved short URLs one photo at a time (and wrote
  a row per miss) on every guest view; they are now warmed in one pass like every other grid
- **Invited Sign-Up 500**: `users/sign_up/:invitation_token` was declared outside `devise_scope`,
  so the request carried no Devise mapping and the form raised
  `undefined method 'validatable?' for nil` — the one link an invited person follows
- **ExifTool Integration**: Fixed missing exiftool dependency in Docker containers
- **Authentication Errors**: Fixed `undefined method 'resource_persisted?'` in SessionsController
- **Album Photo Management**: Improved photo addition/removal from albums
- **Background Processing**: Better error handling in image processing jobs
- **Session Management**: Fixed session expiration and cleanup processes

### Security
- **Link Previews Never Show Photos**: the app published no Open Graph tags, so chat apps and
  social sites scraped the page for the largest image — pasting a shared-album link reproduced
  one of the family's photos as the preview thumbnail. Every page now declares a fixed app-icon
  `og:image`, a `summary` (not `summary_large_image`) Twitter card, and generic preview text
  that names neither the album nor its owner
- **Rate Limiting**: Added progressive lockout for failed login attempts
- **Session Security**: Enhanced guest session management with revocation capabilities
- **Input Validation**: Improved file upload validation and security
- **Password Protection**: Secure external album sharing with bcrypt-encrypted passwords
- **CSRF Protection**: Enhanced cross-site request forgery protection

### Technical Improvements
- **Job Processing**: Added dedicated queues for different types of background work
- **Database Performance**: Optimized queries for photo and album operations
- **Error Handling**: Comprehensive error handling and logging throughout the application
- **Code Quality**: Added RuboCop configuration and code style enforcement
- **Testing**: Increased test coverage across models, controllers, and features

## [1.0.0] - 2025-01-XX

### Added
- Initial release of Family Photo Share
- User authentication with Devise
- Family groups with invite-only access
- Photo upload and management
- Album organization with privacy controls
- Background image processing with Sidekiq
- Email invitations for family members
- External album sharing with password protection
- QR code generation for easy sharing
- Responsive design for mobile devices
- Docker support for easy deployment

### Features
- **Photo Management**: Upload, organize, and share photos
- **Family Groups**: Create private family spaces
- **Albums**: Organize photos with customizable privacy
- **Image Processing**: Automatic thumbnails and optimization
- **Bulk Upload**: Multiple photo upload with progress tracking
- **Guest Access**: Temporary access for external users
- **Search**: Filter photos by title, description, location, and date
- **Metadata**: Automatic extraction of photo metadata (EXIF data)

### Technical Stack
- Ruby on Rails 8.0
- PostgreSQL 15
- Redis for caching and job queuing
- Sidekiq for background processing
- Active Storage for file management
- Stimulus.js for frontend interactivity
- Docker for containerization