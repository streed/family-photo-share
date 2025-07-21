class FamilyInvitationMailer < ApplicationMailer
  def invitation_email(invitation)
    @invitation = invitation
    @family = invitation.family
    @inviter = invitation.inviter
    @accept_url = accept_invitation_url(invitation.token)
    @decline_url = decline_invitation_url(invitation.token)
    
    mail(
      to: @invitation.email,
      subject: "#{@inviter.display_name_or_full_name} invited you to join #{@family.name} on Family Photo Share"
    )
  end
end
