class TranscriptionJob < ApplicationRecord
  belongs_to :user
  has_many :job_pages, dependent: :destroy
  has_many :journal_entries, dependent: :nullify
  has_many :page_credits

  enum :status, {
    pending: "pending",
    uploading: "uploading",
    processing: "processing",
    post_processing: "post_processing",
    completed: "completed",
    failed: "failed"
  }, default: :pending

  scope :active, -> { where.not(status: [:completed, :failed]) }
  scope :expired, -> { where("expires_at < ?", Time.current) }

  after_create :set_expiration

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

  def all_pages_complete?
    job_pages.where.not(status: [:ocr_complete, :failed]).empty?
  end

  def completed_pages
    job_pages.where(status: :ocr_complete)
  end

  private

  def set_expiration
    update_column(:expires_at, 30.days.from_now)
  end
end
