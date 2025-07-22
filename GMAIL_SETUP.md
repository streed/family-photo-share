# Gmail SMTP Setup Guide

This guide helps you configure Gmail to send emails from Family Photo Share.

## Prerequisites

1. A Gmail account
2. 2-factor authentication enabled on your Google account

## Step-by-Step Setup

### 1. Enable 2-Factor Authentication

1. Go to your [Google Account settings](https://myaccount.google.com/)
2. Click on "Security" in the left sidebar
3. Under "Signing in to Google", click on "2-Step Verification"
4. Follow the prompts to enable 2FA

### 2. Generate an App Password

1. Go to [App passwords](https://myaccount.google.com/apppasswords)
2. Select "Mail" from the "Select app" dropdown
3. Select "Other" from the "Select device" dropdown
4. Enter "Family Photo Share" as the name
5. Click "Generate"
6. Copy the 16-character password (spaces don't matter)

### 3. Configure Environment Variables

Add these to your `.env` file:

```bash
# Gmail SMTP Configuration
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=gmail.com
SMTP_USERNAME=your.email@gmail.com
SMTP_PASSWORD=xxxx xxxx xxxx xxxx  # Your 16-character app password
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true
```

### 4. Test Your Configuration

```bash
# For local development
TEST_EMAIL=your@email.com rails email:test

# For Docker
docker-compose exec web rails email:test TEST_EMAIL=your@email.com
```

## Troubleshooting

### "Authentication failed" error

- Make sure you're using the App Password, not your regular Gmail password
- Verify the app password is exactly 16 characters (you can include or omit spaces)
- Check that 2FA is enabled on your Google account

### "Connection refused" error

- Verify SMTP_ADDRESS is set to `smtp.gmail.com`
- Check that SMTP_PORT is set to `587`
- Ensure your firewall allows outbound connections on port 587

### Emails not being received

- Check your spam folder
- Verify the recipient email address is correct
- Look at the Rails logs for any error messages
- Try the test email command to isolate issues

### Gmail Security Alert

If you receive a security alert from Google:
- This is normal when first setting up
- The app password ensures secure access
- You can review connected apps in your Google Account settings

## Alternative Email Services

If you prefer not to use Gmail, you can use other SMTP services:

- **SendGrid**: Professional email delivery service with free tier
- **Mailgun**: Developer-friendly email service
- **Amazon SES**: Cost-effective for high volume
- **Postmark**: Focused on transactional email

Just update the SMTP settings accordingly in your `.env` file.

## Security Notes

- Never commit your `.env` file to version control
- App passwords are more secure than using your regular password
- Consider using a dedicated Gmail account for your application
- Regularly review your Google Account's security settings

## Development Mode

If you don't want to configure email for development, the app defaults to `letter_opener` which opens emails in your browser instead of sending them. Just leave the SMTP variables unset in development.