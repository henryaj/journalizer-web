class FeedbackMailer < ApplicationMailer
  ADMIN_EMAIL = ENV.fetch("ADMIN_EMAIL", "henry@henrystanley.com")

  def submit(user, message)
    @user = user
    @message = message
    mail(
      to: ADMIN_EMAIL,
      reply_to: user.email_address,
      subject: "Feedback from #{user.display_name}"
    )
  end
end
