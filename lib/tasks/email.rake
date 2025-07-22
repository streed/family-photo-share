namespace :email do
  desc "Test email configuration by sending a test email"
  task test: :environment do
    if ENV['TEST_EMAIL'].blank?
      puts "Please provide a TEST_EMAIL environment variable"
      puts "Usage: TEST_EMAIL=your@email.com rails email:test"
      exit 1
    end

    test_email = ENV['TEST_EMAIL']
    
    puts "Sending test email to: #{test_email}"
    puts "Using SMTP settings:"
    puts "  Address: #{ENV['SMTP_ADDRESS'] || 'Not configured (using letter_opener)'}"
    puts "  Port: #{ENV.fetch('SMTP_PORT', 587)}"
    puts "  Username: #{ENV['SMTP_USERNAME'] || 'Not configured'}"
    puts ""

    begin
      TestMailer.test_email(test_email).deliver_now
      puts "✅ Test email sent successfully!"
      puts "Check your inbox at: #{test_email}"
    rescue => e
      puts "❌ Failed to send test email:"
      puts e.message
      puts ""
      puts "Common issues:"
      puts "1. Make sure you're using an App Password, not your Gmail password"
      puts "2. Enable 2-factor authentication on your Google account"
      puts "3. Generate app password at: https://myaccount.google.com/apppasswords"
      puts "4. Check that all SMTP_* environment variables are set correctly"
    end
  end

  desc "Test family invitation emails"
  task test_invitations: :environment do
    puts "Testing invitation email templates..."
    
    # Create test data
    family = Family.first || Family.create!(name: "Test Family", created_by: User.first)
    inviter = family.created_by
    invitation = family.family_invitations.build(
      email: ENV.fetch('TEST_EMAIL', 'test@example.com'),
      inviter: inviter
    )
    invitation.save(validate: false) # Skip validation for test
    
    puts "Testing invitation email..."
    FamilyInvitationMailer.invitation_email(invitation).deliver_now
    
    puts "Testing acceptance notification email..."
    test_member = User.new(
      email: invitation.email,
      first_name: "Test",
      last_name: "User"
    )
    FamilyInvitationMailer.acceptance_notification(invitation, test_member).deliver_now
    
    puts "✅ Invitation email templates tested!"
    puts "Check your email client or letter_opener for the test emails"
    
    # Clean up
    invitation.destroy
  end
end