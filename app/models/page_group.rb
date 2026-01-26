class PageGroup < ApplicationRecord
  belongs_to :transcription_job
  has_many :job_pages, dependent: :nullify

  validates :group_number, presence: true,
                           uniqueness: { scope: :transcription_job_id }

  scope :in_order, -> { order(:group_number) }

  def combined_ocr_text
    job_pages.in_order.map(&:raw_ocr_text).compact.join("\n\n")
  end

  def page_numbers
    job_pages.in_order.pluck(:page_number)
  end
end
