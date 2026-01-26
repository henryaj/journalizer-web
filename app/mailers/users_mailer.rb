class UsersMailer < ApplicationMailer
  def welcome(user)
    @user = user
    mail(to: user.email_address, subject: "Welcome to Journalizer")
  end
end
