class AnalyticsService
  def initialize(period: nil)
    @start_date = case period
                  when "7_days" then 7.days.ago
                  when "30_days" then 30.days.ago
                  when "all_time", nil then nil
                  else 7.days.ago
                  end
  end

  # User metrics
  def total_users
    User.count
  end

  def new_users
    users_scope.count
  end

  def oauth_users
    users_scope.where.not(provider: nil).count
  end

  def password_users
    users_scope.where(provider: nil).count
  end

  def users_with_entries
    User.joins(:journal_entries).distinct.count
  end

  def users_with_credits
    User.where("credit_balance > 0").count
  end

  def active_users
    if @start_date
      User.joins(:transcription_jobs)
          .where("transcription_jobs.created_at >= ?", @start_date)
          .distinct.count
    else
      User.joins(:transcription_jobs).distinct.count
    end
  end

  # Transcription job metrics
  def total_jobs
    jobs_scope.count
  end

  def completed_jobs
    jobs_scope.where(status: "completed").count
  end

  def failed_jobs
    jobs_scope.where(status: "failed").count
  end

  def pending_jobs
    TranscriptionJob.where.not(status: %w[completed failed]).count
  end

  def total_pages_processed
    jobs_scope.where(status: "completed").sum(:page_count)
  end

  def average_pages_per_job
    completed = jobs_scope.where(status: "completed")
    return 0 if completed.count.zero?
    (completed.sum(:page_count).to_f / completed.count).round(1)
  end

  # Journal entry metrics
  def total_entries
    entries_scope.count
  end

  def synced_entries
    entries_scope.where(synced: true).count
  end

  def unsynced_entries
    entries_scope.where(synced: false).count
  end

  # Credit/Revenue metrics
  def total_credits_purchased
    credits_scope.where(transaction_type: "purchase").sum(:amount)
  end

  def total_credits_used
    credits_scope.where(transaction_type: "usage").sum(:amount).abs
  end

  def total_bonus_credits
    credits_scope.where(transaction_type: "bonus").sum(:amount)
  end

  def purchase_count
    credits_scope.where(transaction_type: "purchase")
                 .where.not(stripe_payment_intent_id: nil)
                 .select(:stripe_payment_intent_id).distinct.count
  end

  def conversion_rate
    total = User.count
    return 0 if total.zero?

    purchasers = PageCredit.where(transaction_type: "purchase")
                           .select(:user_id).distinct.count
    ((purchasers.to_f / total) * 100).round(1)
  end

  private

  def users_scope
    @start_date ? User.where("created_at >= ?", @start_date) : User
  end

  def jobs_scope
    @start_date ? TranscriptionJob.where("created_at >= ?", @start_date) : TranscriptionJob
  end

  def entries_scope
    @start_date ? JournalEntry.where("created_at >= ?", @start_date) : JournalEntry
  end

  def credits_scope
    @start_date ? PageCredit.where("created_at >= ?", @start_date) : PageCredit
  end
end
