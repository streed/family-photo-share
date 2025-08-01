class TestMailer < ApplicationMailer
  def test_email(recipient_email)
    @test_time = Time.current
    @app_name = "Family Photo Share"

    mail(
      to: recipient_email,
      subject: "Test Email from Family Photo Share - #{@test_time.strftime('%Y-%m-%d %H:%M')}"
    )
  end
end
