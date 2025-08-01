# Preview all emails at http://localhost:3000/rails/mailers/family_invitation_mailer_mailer
class FamilyInvitationMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/family_invitation_mailer_mailer/invitation_email
  delegate :invitation_email, to: :FamilyInvitationMailer
end
