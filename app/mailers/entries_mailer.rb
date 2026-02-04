class EntriesMailer < ApplicationMailer
  def entry_transcribed(entry)
    @entry = entry
    @user = entry.user

    mail(
      to: @user.email_address,
      subject: "New entry transcribed: #{@entry.title.truncate(50)}"
    )
  end

  def daily_digest(user, entries)
    @user = user
    @entries = entries
    @date = Date.current

    mail(
      to: user.email_address,
      subject: "Your Journalizer digest for #{@date.strftime('%B %d, %Y')}"
    )
  end
end
