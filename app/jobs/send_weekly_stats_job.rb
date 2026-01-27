class SendWeeklyStatsJob < ApplicationJob
  queue_as :default

  def perform
    AdminStatsMailer.weekly_stats.deliver_now
    Rails.logger.info "Sent weekly stats email to #{AdminStatsMailer::STATS_RECIPIENT}"
  end
end
