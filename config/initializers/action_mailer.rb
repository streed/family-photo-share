# Action Mailer Configuration
# This file ensures consistent email configuration across environments

Rails.application.configure do
  # Default from address for all mailers
  config.action_mailer.default_options = {
    from: ENV.fetch('SMTP_USERNAME', 'noreply@localhost'),
    reply_to: ENV.fetch('SMTP_USERNAME', 'noreply@localhost')
  }

  # Ensure emails are sent asynchronously in production
  if Rails.env.production?
    config.action_mailer.deliver_later_queue_name = :default
  end
end

# Gmail-specific configuration notes:
# 1. Enable 2-factor authentication on your Google account
# 2. Generate an app password at: https://myaccount.google.com/apppasswords
# 3. Use the 16-character app password as SMTP_PASSWORD
# 4. Set SMTP_USERNAME to your full Gmail address (e.g., user@gmail.com)
# 5. Set SMTP_DOMAIN to gmail.com