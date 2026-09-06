class UploadToOcrJob < ApplicationJob
  queue_as :ocr_upload

  # Well above the ~300 DPI HandwritingOCR wants for an A5 page, far below what
  # a phone camera hands us.
  MAX_DIMENSION = 3000

  # Custom retry for rate limiting
  retry_on HandwritingOcr::RateLimitError, wait: 2.seconds, attempts: 5
  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def self.normalize(source_path, dest_path)
    image = Vips::Image.thumbnail(source_path, MAX_DIMENSION, height: MAX_DIMENSION, size: :down)
    image = image.flatten(background: 255) if image.has_alpha?
    image.jpegsave(dest_path, Q: 90)
  end

  def perform(page_id)
    page = JobPage.find(page_id)
    return unless page.pending? || page.failed?

    page.mark_uploaded!

    unless page.image.attached?
      page.mark_failed!("No image attached")
      check_job_failure(page.transcription_job)
      return
    end

    doc_id = page.image.open do |source|
      Tempfile.create([ "ocr_page", ".jpg" ]) do |jpeg|
        self.class.normalize(source.path, jpeg.path)
        jpeg.binmode
        jpeg.rewind

        HandwritingOcr::Client.new.upload(
          jpeg,
          filename: "page_#{page.page_number}.jpg",
          content_type: "image/jpeg"
        )
      end
    end

    page.mark_ocr_submitted!(doc_id)

    # Start polling for this page
    PollOcrResultJob.set(wait: 2.seconds).perform_later(page_id)

  rescue HandwritingOcr::Error, Vips::Error => e
    page.mark_failed!(e.message)
    check_job_failure(page.transcription_job)
  end

  private

  def check_job_failure(job)
    # If all pages have failed, mark the job as failed
    if job.job_pages.where(status: :failed).count == job.page_count
      job.mark_failed!("All pages failed to process")
    end
  end
end
