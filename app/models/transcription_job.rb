class TranscriptionJob < ApplicationRecord
  belongs_to :user
  has_many :job_pages, dependent: :destroy
  has_many :page_groups, dependent: :destroy
  has_many :journal_entries, dependent: :nullify
  has_many :page_credits

  enum :status, {
    awaiting_review: "awaiting_review",
    pending: "pending",
    awaiting_credits: "awaiting_credits",
    uploading: "uploading",
    processing: "processing",
    post_processing: "post_processing",
    completed: "completed",
    failed: "failed"
  }, default: :awaiting_review

  scope :active, -> { where.not(status: [:completed, :failed]) }
  scope :in_progress, -> { where.not(status: [:completed, :failed, :awaiting_review]) }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :awaiting_credits, -> { where(status: :awaiting_credits) }
  scope :awaiting_review, -> { where(status: :awaiting_review) }

  after_create :set_expiration

  def mark_reviewed!
    update!(reviewed_at: Time.current, status: :pending)
  end

  def mark_started!
    update!(status: :uploading, started_at: Time.current)
  end

  def mark_processing!
    update!(status: :processing)
  end

  def mark_post_processing!
    update!(status: :post_processing)
  end

  def mark_completed!
    update!(status: :completed, completed_at: Time.current)
  end

  def mark_failed!(message)
    update!(status: :failed, error_message: message, completed_at: Time.current)
  end

  def credits_required
    page_count
  end

  def can_resume_with_credits?(available_credits)
    awaiting_credits? && available_credits >= credits_required
  end

  def resume!
    return unless awaiting_credits?
    update!(status: :pending)
    OcrPipelineJob.perform_later(id)
  end

  def process_with_partial_credits!(available_credits)
    transaction do
      pages_to_process = [available_credits, page_count].min

      # Mark excess pages as skipped (won't be processed)
      job_pages.order(:page_number).offset(pages_to_process).update_all(
        status: :skipped,
        error_message: "Skipped due to insufficient credits"
      )

      # Update job with actual page count being processed
      update!(
        status: :pending,
        page_count: pages_to_process
      )

      # Deduct credits
      user.deduct_credits!(pages_to_process, job: self)
    end

    # Start processing
    OcrPipelineJob.perform_later(id)
  end

  def all_pages_complete?
    job_pages.where.not(status: [:ocr_complete, :failed, :skipped]).empty?
  end

  def completed_pages
    job_pages.where(status: :ocr_complete)
  end

  def has_manual_groups?
    page_groups.any?
  end

  def ungrouped_pages
    job_pages.where(page_group_id: nil)
  end

  private

  def set_expiration
    update_column(:expires_at, 30.days.from_now)
  end
end
