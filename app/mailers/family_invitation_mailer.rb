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

  def acceptance_notification(invitation, new_member)
    @invitation = invitation
    @family = invitation.family
    @inviter = invitation.inviter
    @new_member = new_member
    @family_url = family_url(@family)

    mail(
      to: @inviter.email,
      subject: "#{@new_member.display_name_or_full_name} has joined #{@family.name}!"
    )
  end
end
