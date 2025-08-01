class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_USERNAME", "noreply@family-photo-share.local")
  layout "mailer"
end
