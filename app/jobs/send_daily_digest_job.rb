class SendDailyDigestJob < ApplicationJob
  queue_as :default

  def perform
    User.where(email_preference: "daily_digest").find_each do |user|
      entries = user.journal_entries
                    .not_expired
                    .where("created_at >= ?", 24.hours.ago)
                    .order(created_at: :desc)

      next if entries.empty?

      EntriesMailer.daily_digest(user, entries).deliver_now
      Rails.logger.info "Sent daily digest to #{user.email_address} with #{entries.count} entries"
    end
  end
end
