class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    @credit_balance = Current.user.credit_balance
    @recent_entries = Current.user.journal_entries.not_expired.recent.limit(10)
    @pending_jobs = Current.user.transcription_jobs.active
  end
end
