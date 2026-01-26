class JobPage < ApplicationRecord
  belongs_to :transcription_job
  belongs_to :page_group, optional: true
  has_one_attached :image

  enum :status, {
    pending: "pending",
    skipped: "skipped",
    uploaded: "uploaded",
    ocr_submitted: "ocr_submitted",
    ocr_processing: "ocr_processing",
    ocr_complete: "ocr_complete",
    failed: "failed"
  }, default: :pending

  validates :page_number, presence: true,
                          uniqueness: { scope: :transcription_job_id }

  scope :in_order, -> { order(:page_number) }

  def mark_uploaded!
    update!(status: :uploaded)
  end

  def mark_ocr_submitted!(doc_id)
    update!(status: :ocr_submitted, handwriting_ocr_doc_id: doc_id)
  end

  def mark_ocr_processing!
    update!(status: :ocr_processing)
  end

  def mark_ocr_complete!(text)
    update!(status: :ocr_complete, raw_ocr_text: text)
  end

  def mark_failed!(message)
    update!(status: :failed, error_message: message)
  end
end
