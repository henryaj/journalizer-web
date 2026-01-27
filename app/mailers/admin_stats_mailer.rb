class AdminStatsMailer < ApplicationMailer
  STATS_RECIPIENT = ENV.fetch("ADMIN_STATS_EMAIL", ENV.fetch("ADMIN_EMAIL", "henry@henrystanley.com"))

  def weekly_stats
    @week_analytics = AnalyticsService.new(period: "7_days")
    @all_time_analytics = AnalyticsService.new(period: "all_time")
    @week_start = 7.days.ago.to_date
    @week_end = Date.current

    mail(
      to: STATS_RECIPIENT,
      subject: "Journalizer Weekly Stats: #{@week_start.strftime('%b %d')} - #{@week_end.strftime('%b %d, %Y')}"
    )
  end
end
