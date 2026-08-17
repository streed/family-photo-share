require "rails_helper"

RSpec.describe FamilyInvitationMailer, type: :mailer do
  let(:inviter) { create(:user, first_name: "Ada", last_name: "Lovelace") }
  let(:family) { create(:family, name: "The Lovelaces", created_by: inviter) }
  let(:invitation) do
    create(:family_invitation, family: family, inviter: inviter, email: "guest@example.org")
  end

  describe "invitation_email" do
    let(:mail) { described_class.invitation_email(invitation) }

    it "addresses the invited email" do
      expect(mail.to).to eq([ "guest@example.org" ])
    end

    it "names the inviter and the family in the subject" do
      expect(mail.subject).to eq(
        "#{inviter.display_name_or_full_name} invited you to join The Lovelaces on Family Photo Share"
      )
    end

    it "sends from the configured address" do
      expect(mail.from).to eq([ ENV.fetch("SMTP_USERNAME", "noreply@family-photo-share.local") ])
    end

    it "includes working accept and decline links" do
      # Decode the text part: the multipart body is quoted-printable, so the raw
      # token does not appear literally in mail.body.encoded.
      text = mail.text_part.decoded

      expect(text).to include(accept_invitation_url(invitation.token))
      expect(text).to include(decline_invitation_url(invitation.token))
    end

    it "mentions the family name in the body" do
      expect(mail.text_part.decoded).to include("The Lovelaces")
    end
  end

  describe "acceptance_notification" do
    let(:new_member) { create(:user, first_name: "Grace", last_name: "Hopper") }
    let(:mail) { described_class.acceptance_notification(invitation, new_member) }

    it "notifies the inviter" do
      expect(mail.to).to eq([ inviter.email ])
    end

    it "names the new member in the subject" do
      expect(mail.subject).to eq(
        "#{new_member.display_name_or_full_name} has joined The Lovelaces!"
      )
    end

    it "links to the family" do
      expect(mail.text_part.decoded).to include(family_url(family))
    end
  end
end
