# Phase 6, Ticket 2: Security Hardening and Error Handling

**Priority**: High  
**Estimated Time**: 3-4 hours  
**Prerequisites**: Completed Phase 6, Ticket 1  

## Objective

Implement comprehensive security measures and robust error handling to protect user data, prevent common attacks, and provide graceful error recovery throughout the application.

## Acceptance Criteria

- [ ] Input validation and sanitization implemented
- [ ] File upload security measures in place
- [ ] Rate limiting configured for critical endpoints
- [ ] CSRF protection verified and enhanced
- [ ] Content Security Policy (CSP) configured
- [ ] Error handling with user-friendly messages
- [ ] Security headers configured
- [ ] Audit logging for sensitive operations
- [ ] Data encryption for sensitive fields

## Technical Requirements

### 1. File Upload Security

Create `app/validators/image_validator.rb`:

```ruby
class ImageValidator < ActiveModel::EachValidator
  ALLOWED_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze
  MAX_FILE_SIZE = 10.megabytes
  
  def validate_each(record, attribute, value)
    return unless value.attached?

    validate_content_type(record, attribute, value)
    validate_file_size(record, attribute, value)
    validate_image_dimensions(record, attribute, value)
    validate_file_signature(record, attribute, value)
  end

  private

  def validate_content_type(record, attribute, value)
    unless ALLOWED_TYPES.include?(value.content_type)
      record.errors.add(attribute, 'must be a valid image file (JPEG, PNG, GIF, or WebP)')
    end
  end

  def validate_file_size(record, attribute, value)
    if value.byte_size > MAX_FILE_SIZE
      record.errors.add(attribute, "must be less than #{MAX_FILE_SIZE / 1.megabyte}MB")
    end
  end

  def validate_image_dimensions(record, attribute, value)
    return unless value.blob.analyzed?
    
    metadata = value.blob.metadata
    width = metadata['width']
    height = metadata['height']
    
    if width && height
      if width > 5000 || height > 5000
        record.errors.add(attribute, 'dimensions are too large (maximum 5000x5000 pixels)')
      end
      
      if width < 50 || height < 50
        record.errors.add(attribute, 'dimensions are too small (minimum 50x50 pixels)')
      end
    end
  end

  def validate_file_signature(record, attribute, value)
    # Check file signature to prevent malicious files
    signature = value.blob.download(0..10)
    
    case value.content_type
    when 'image/jpeg'
      unless signature.start_with?("\xFF\xD8\xFF".force_encoding('ASCII-8BIT'))
        record.errors.add(attribute, 'appears to be corrupted or not a valid JPEG')
      end
    when 'image/png'
      unless signature.start_with?("\x89PNG\r\n\x1A\n".force_encoding('ASCII-8BIT'))
        record.errors.add(attribute, 'appears to be corrupted or not a valid PNG')
      end
    when 'image/gif'
      unless signature.start_with?("GIF87a".force_encoding('ASCII-8BIT')) || 
             signature.start_with?("GIF89a".force_encoding('ASCII-8BIT'))
        record.errors.add(attribute, 'appears to be corrupted or not a valid GIF')
      end
    end
  rescue => e
    Rails.logger.error "File signature validation error: #{e.message}"
    record.errors.add(attribute, 'could not be validated')
  end
end
```

Update `app/models/photo.rb`:

```ruby
class Photo < ApplicationRecord
  # ... existing code ...

  validates :image, image: true
  validate :scan_for_malware, if: -> { image.attached? }

  private

  def scan_for_malware
    return unless Rails.env.production?
    
    # In production, you might integrate with a service like ClamAV
    # For now, we'll just check file size and type
    if image.blob.byte_size > 50.megabytes
      errors.add(:image, 'file is suspiciously large')
    end
  end
end
```

### 2. Input Validation and Sanitization

Create `app/validators/content_validator.rb`:

```ruby
class ContentValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    # Check for potentially malicious content
    if contains_script_tags?(value)
      record.errors.add(attribute, 'contains potentially unsafe content')
    end

    if contains_sql_injection_patterns?(value)
      record.errors.add(attribute, 'contains invalid characters')
    end

    if too_many_links?(value)
      record.errors.add(attribute, 'contains too many links')
    end
  end

  private

  def contains_script_tags?(value)
    value.match?(%r{<script|javascript:|data:text/html|vbscript:|onload=|onerror=}i)
  end

  def contains_sql_injection_patterns?(value)
    # Basic SQL injection pattern detection
    patterns = [
      /(\w+\s*=\s*\w+\s*(and|or)\s*\w+\s*=\s*\w+)/i,
      /(union\s+select|drop\s+table|delete\s+from|insert\s+into)/i,
      /('.*--|\)\s*;\s*drop|\)\s*;\s*delete)/i
    ]
    
    patterns.any? { |pattern| value.match?(pattern) }
  end

  def too_many_links?(value)
    link_count = value.scan(/https?:\/\//).length
    link_count > 3
  end
end
```

Update model validations in `app/models/`:

```ruby
# In app/models/user.rb
validates :first_name, :last_name, content: true
validates :bio, content: true

# In app/models/album.rb  
validates :title, :description, content: true

# In app/models/family.rb
validates :name, :description, content: true

# In app/models/album_photo.rb
validates :caption, content: true
```

### 3. Rate Limiting

Create `app/controllers/concerns/rate_limitable.rb`:

```ruby
module RateLimitable
  extend ActiveSupport::Concern

  included do
    before_action :check_rate_limit, only: [:create, :update]
  end

  private

  def check_rate_limit
    return unless should_rate_limit?

    key = rate_limit_key
    current_count = Rails.cache.read(key) || 0
    
    if current_count >= rate_limit_threshold
      render json: { error: 'Rate limit exceeded. Please try again later.' }, 
             status: :too_many_requests
      return
    end

    Rails.cache.write(key, current_count + 1, expires_in: rate_limit_window)
  end

  def should_rate_limit?
    # Rate limit for non-authenticated users and new accounts
    !user_signed_in? || (current_user.created_at > 1.day.ago)
  end

  def rate_limit_key
    if user_signed_in?
      "rate_limit:user:#{current_user.id}:#{controller_name}:#{action_name}"
    else
      "rate_limit:ip:#{request.remote_ip}:#{controller_name}:#{action_name}"
    end
  end

  def rate_limit_threshold
    case "#{controller_name}##{action_name}"
    when 'photos#create', 'photos#bulk_create'
      user_signed_in? ? 50 : 10  # 50 uploads per hour for users, 10 for guests
    when 'family_members#invite'
      5  # 5 invitations per hour
    when 'family_invitations#accept'
      3  # 3 invitation accepts per hour
    else
      user_signed_in? ? 100 : 20  # Default limits
    end
  end

  def rate_limit_window
    1.hour
  end
end
```

Include in relevant controllers:

```ruby
# In app/controllers/photos_controller.rb
class PhotosController < ApplicationController
  include RateLimitable
  # ... existing code ...
end

# In app/controllers/family_members_controller.rb
class FamilyMembersController < ApplicationController
  include RateLimitable
  # ... existing code ...
end
```

### 4. Security Headers and CSP

Create `config/initializers/security.rb`:

```ruby
Rails.application.configure do
  # Force SSL in production
  config.force_ssl = Rails.env.production?

  # Security headers
  config.ssl_options = {
    hsts: {
      expires: 1.year,
      subdomains: true,
      preload: true
    }
  }
end

# Content Security Policy
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data, :blob
  policy.object_src  :none
  policy.script_src  :self, :https
  policy.style_src   :self, :https, :unsafe_inline
  
  # Allow specific domains if needed
  # policy.connect_src :self, :https, "wss://example.com"
  
  # For development, allow unsafe-eval for better debugging
  if Rails.env.development?
    policy.script_src :self, :https, :unsafe_eval
  end
end

# Report CSP violations in production
Rails.application.config.content_security_policy_report_only = Rails.env.development?
Rails.application.config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
```

Create `app/controllers/concerns/security_headers.rb`:

```ruby
module SecurityHeaders
  extend ActiveSupport::Concern

  included do
    before_action :set_security_headers
  end

  private

  def set_security_headers
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'
    
    # Remove server information
    response.headers.delete('Server')
    response.headers.delete('X-Powered-By')
  end
end
```

Include in `ApplicationController`:

```ruby
class ApplicationController < ActionController::Base
  include SecurityHeaders
  # ... existing code ...
end
```

### 5. Error Handling

Create `app/controllers/concerns/error_handler.rb`:

```ruby
module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_invalid_record
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from Pundit::NotAuthorizedError, with: :handle_not_authorized if defined?(Pundit)
  end

  private

  def handle_standard_error(exception)
    log_error(exception)
    
    if Rails.env.production?
      render_error_page(500, "We're sorry, but something went wrong.")
    else
      raise exception
    end
  end

  def handle_not_found(exception)
    log_error(exception, :warn)
    render_error_page(404, "The page you were looking for doesn't exist.")
  end

  def handle_invalid_record(exception)
    log_error(exception, :warn)
    
    if request.xhr?
      render json: { 
        error: 'Validation failed', 
        details: exception.record.errors.full_messages 
      }, status: :unprocessable_entity
    else
      flash[:alert] = exception.record.errors.full_messages.join(', ')
      redirect_back(fallback_location: root_path)
    end
  end

  def handle_parameter_missing(exception)
    log_error(exception, :warn)
    
    if request.xhr?
      render json: { error: 'Missing required parameters' }, status: :bad_request
    else
      flash[:alert] = 'Required information is missing.'
      redirect_back(fallback_location: root_path)
    end
  end

  def handle_not_authorized(exception)
    log_error(exception, :warn)
    
    if user_signed_in?
      flash[:alert] = "You don't have permission to perform this action."
      redirect_back(fallback_location: root_path)
    else
      flash[:notice] = 'Please sign in to continue.'
      redirect_to new_user_session_path
    end
  end

  def render_error_page(status, message)
    respond_to do |format|
      format.html { render 'errors/error', locals: { status: status, message: message }, status: status }
      format.json { render json: { error: message }, status: status }
    end
  end

  def log_error(exception, level = :error)
    context = {
      user_id: current_user&.id,
      request_id: request.uuid,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      url: request.url,
      params: params.except('controller', 'action').inspect
    }

    message = "#{exception.class}: #{exception.message}"
    Rails.logger.send(level, "#{message} | Context: #{context.inspect}")
    
    # In production, you might want to send to external error tracking
    # e.g., Honeybadger.notify(exception, context: context)
  end
end
```

Create error pages `app/views/errors/error.html.erb`:

```erb
<div class="error-page">
  <div class="error-container">
    <div class="error-icon">
      <% case status %>
      <% when 404 %>
        🔍
      <% when 403 %>
        🔒
      <% when 500 %>
        🔧
      <% else %>
        ⚠️
      <% end %>
    </div>
    
    <h1>Oops! Something went wrong</h1>
    <h2><%= status %> Error</h2>
    
    <p class="error-message"><%= message %></p>
    
    <div class="error-actions">
      <%= link_to "← Go Back", :back, class: "btn btn-secondary" %>
      <%= link_to "Home", root_path, class: "btn btn-primary" %>
    </div>
    
    <% if Rails.env.development? %>
      <div class="error-debug">
        <details>
          <summary>Debug Information</summary>
          <pre><%= params.inspect %></pre>
        </details>
      </div>
    <% end %>
  </div>
</div>

<style>
.error-page {
  min-height: 60vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
}

.error-container {
  text-align: center;
  padding: 3rem;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  backdrop-filter: blur(10px);
  max-width: 500px;
}

.error-icon {
  font-size: 4rem;
  margin-bottom: 1rem;
}

.error-container h1 {
  margin: 0 0 0.5rem 0;
  font-size: 2rem;
}

.error-container h2 {
  margin: 0 0 1rem 0;
  opacity: 0.8;
  font-weight: normal;
}

.error-message {
  margin-bottom: 2rem;
  opacity: 0.9;
}

.error-actions {
  display: flex;
  gap: 1rem;
  justify-content: center;
}

.error-debug {
  margin-top: 2rem;
  text-align: left;
}

.error-debug pre {
  background: rgba(0, 0, 0, 0.2);
  padding: 1rem;
  border-radius: 4px;
  font-size: 0.8rem;
  overflow-x: auto;
}
</style>
```

### 6. Audit Logging

Create `app/models/audit_log.rb`:

```ruby
class AuditLog < ApplicationRecord
  belongs_to :user, optional: true
  
  validates :action, :resource_type, presence: true
  validates :ip_address, format: { with: /\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/ }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_resource, ->(resource) { where(resource_type: resource.class.name, resource_id: resource.id) }

  SENSITIVE_ACTIONS = %w[
    family_created family_deleted
    member_invited member_removed member_role_changed
    album_created album_deleted album_privacy_changed
    photo_uploaded photo_deleted
    user_signed_in user_signed_out user_registered
  ].freeze

  def self.log(action, user: nil, resource: nil, ip_address: nil, details: {})
    return unless SENSITIVE_ACTIONS.include?(action.to_s)

    create!(
      action: action.to_s,
      user: user,
      resource_type: resource&.class&.name,
      resource_id: resource&.id,
      ip_address: ip_address,
      details: details.to_json,
      created_at: Time.current
    )
  rescue => e
    Rails.logger.error "Failed to create audit log: #{e.message}"
  end
end
```

Create migration:

```bash
bundle exec rails generate model AuditLog action:string user:references resource_type:string resource_id:integer ip_address:string details:text
```

Update the migration:

```ruby
class CreateAuditLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :audit_logs do |t|
      t.string :action, null: false
      t.references :user, foreign_key: true, null: true
      t.string :resource_type
      t.integer :resource_id
      t.string :ip_address
      t.text :details
      t.timestamp :created_at, null: false
    end

    add_index :audit_logs, [:user_id, :created_at]
    add_index :audit_logs, [:resource_type, :resource_id]
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
  end
end
```

Create `app/controllers/concerns/auditable.rb`:

```ruby
module Auditable
  extend ActiveSupport::Concern

  included do
    after_action :log_audit_trail, only: [:create, :update, :destroy]
  end

  private

  def log_audit_trail
    return unless response.successful?

    action_name = audit_action_name
    resource = audit_resource
    
    return unless action_name && resource

    AuditLog.log(
      action_name,
      user: current_user,
      resource: resource,
      ip_address: request.remote_ip,
      details: audit_details
    )
  end

  def audit_action_name
    case "#{controller_name}##{action_name}"
    when 'families#create'
      'family_created'
    when 'families#destroy'
      'family_deleted'
    when 'family_members#invite'
      'member_invited'
    when 'family_members#destroy'
      'member_removed'
    when 'albums#create'
      'album_created'
    when 'albums#destroy'
      'album_deleted'
    when 'photos#create', 'photos#bulk_create'
      'photo_uploaded'
    when 'photos#destroy'
      'photo_deleted'
    end
  end

  def audit_resource
    instance_variable_get("@#{controller_name.singularize}")
  end

  def audit_details
    {
      params: params.except('controller', 'action', 'authenticity_token').to_unsafe_h,
      user_agent: request.user_agent
    }
  end
end
```

### 7. Data Encryption

Create `config/initializers/encryption.rb`:

```ruby
# Encryption for sensitive data
class DataEncryption
  def self.encrypt(value)
    return nil if value.blank?
    
    encryptor.encrypt_and_sign(value.to_s)
  end

  def self.decrypt(value)
    return nil if value.blank?
    
    encryptor.decrypt_and_verify(value)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage
    nil
  end

  private

  def self.encryptor
    key = Rails.application.credentials.encryption_key || Rails.application.secret_key_base[0..31]
    ActiveSupport::MessageEncryptor.new(key)
  end
end

# Encrypted attribute concern
module EncryptedAttributes
  extend ActiveSupport::Concern

  class_methods do
    def encrypted_attribute(attribute)
      define_method "#{attribute}=" do |value|
        super(DataEncryption.encrypt(value))
      end

      define_method attribute do
        encrypted_value = super()
        DataEncryption.decrypt(encrypted_value)
      end
    end
  end
end
```

Update models with sensitive data:

```ruby
# In app/models/album.rb
include EncryptedAttributes
encrypted_attribute :passcode

# In app/models/family_invitation.rb  
include EncryptedAttributes
encrypted_attribute :token
```

## Testing Requirements

### 1. Security Tests
Create `spec/security/file_upload_security_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'File Upload Security', type: :security do
  let(:user) { create(:user) }

  before { sign_in user }

  it 'rejects non-image files' do
    file = fixture_file_upload('spec/fixtures/files/malicious.exe', 'application/exe')
    
    post photos_path, params: { photo: { image: file, title: 'Test' } }
    
    expect(response).to have_http_status(:unprocessable_entity)
    expect(Photo.count).to eq(0)
  end

  it 'rejects oversized files' do
    # Create a large file mock
    large_file = double('file', 
      original_filename: 'large.jpg',
      content_type: 'image/jpeg',
      size: 20.megabytes,
      tempfile: Tempfile.new
    )
    
    allow(large_file).to receive(:read).and_return('fake_image_data')
    
    photo = build(:photo, user: user)
    photo.image.attach(large_file)
    
    expect(photo).not_to be_valid
    expect(photo.errors[:image]).to include(/must be less than/)
  end
end
```

### 2. Rate Limiting Tests
Create `spec/security/rate_limiting_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Rate Limiting', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
    Rails.cache.clear
  end

  it 'rate limits photo uploads' do
    # Make requests up to the limit
    51.times do |i|
      post photos_path, params: { photo: { title: "Photo #{i}" } }
      break if response.status == 429
    end

    expect(response).to have_http_status(:too_many_requests)
  end

  it 'allows requests after rate limit window expires' do
    # Fill up the rate limit
    50.times { post photos_path, params: { photo: { title: 'Test' } } }
    
    # Fast forward time
    travel 2.hours do
      post photos_path, params: { photo: { title: 'After expiry' } }
      expect(response).not_to have_http_status(:too_many_requests)
    end
  end
end
```

### 3. Input Validation Tests  
Create `spec/security/input_validation_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Input Validation', type: :model do
  it 'rejects content with script tags' do
    user = build(:user, bio: '<script>alert("xss")</script>')
    expect(user).not_to be_valid
    expect(user.errors[:bio]).to include(/potentially unsafe content/)
  end

  it 'rejects content with SQL injection patterns' do
    album = build(:album, title: "'; DROP TABLE albums; --")
    expect(album).not_to be_valid
    expect(album.errors[:title]).to include(/invalid characters/)
  end

  it 'allows normal content' do
    user = build(:user, bio: 'I love photography and sharing memories with family!')
    expect(user).to be_valid
  end
end
```

## Files to Create/Modify

- `app/validators/image_validator.rb` - File upload validation
- `app/validators/content_validator.rb` - Content validation
- `app/controllers/concerns/rate_limitable.rb` - Rate limiting
- `app/controllers/concerns/security_headers.rb` - Security headers
- `app/controllers/concerns/error_handler.rb` - Error handling
- `app/controllers/concerns/auditable.rb` - Audit logging
- `app/models/audit_log.rb` - Audit log model
- `config/initializers/security.rb` - Security configuration
- `config/initializers/encryption.rb` - Data encryption
- `app/views/errors/error.html.erb` - Error pages
- Security and validation tests

## Deliverables

1. Comprehensive file upload security measures
2. Input validation and sanitization
3. Rate limiting for critical endpoints
4. Security headers and CSP configuration
5. Robust error handling with user-friendly messages
6. Audit logging for sensitive operations
7. Data encryption for sensitive fields
8. Security test suite

## Notes for Junior Developer

- Security should be implemented in layers (defense in depth)
- Never trust user input - validate and sanitize everything
- Rate limiting helps prevent abuse and DoS attacks
- Error messages should be helpful but not reveal sensitive information
- Audit logs help with compliance and incident investigation
- Security headers protect against common web vulnerabilities
- Regular security testing should be part of your development process

## Security Checklist

- [ ] File uploads are validated for type, size, and content
- [ ] User input is sanitized and validated
- [ ] Rate limiting is in place for sensitive endpoints
- [ ] Security headers are configured
- [ ] Error handling doesn't leak sensitive information
- [ ] Audit logging captures important security events
- [ ] Sensitive data is encrypted at rest
- [ ] CSRF protection is enabled and working
- [ ] SQL injection protection is in place
- [ ] XSS protection is implemented

## Validation Steps

1. Test file upload with various file types
2. Try submitting forms with malicious content
3. Test rate limiting by making rapid requests
4. Verify security headers in browser dev tools
5. Test error handling with invalid inputs
6. Check audit logs are being created
7. Run security test suite: `bundle exec rspec spec/security/`

## Next Steps

After completing this ticket, you'll move to Phase 6, Ticket 3: Production Deployment and Monitoring Setup.