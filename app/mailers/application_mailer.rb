class ApplicationMailer < ActionMailer::Base
  default from: "Journalizer <journalizer@blmc.dev>",
          reply_to: "henry@henrystanley.com"
  layout "mailer"
end
