class UploadToOcrJob < ApplicationJob
  queue_as :ocr_upload

  # Custom retry for rate limiting
  retry_on HandwritingOcr::RateLimitError, wait: 2.seconds, attempts: 5
  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(page_id)
    page = JobPage.find(page_id)
    return unless page.pending? || page.failed?

    page.mark_uploaded!

    # Download from ActiveStorage and upload to OCR service
    unless page.image.attached?
      page.mark_failed!("No image attached")
      check_job_failure(page.transcription_job)
      return
    end

    image_data = page.image.download
    content_type = page.image.content_type

    # Convert HEIC/HEIF to JPEG since HandwritingOCR doesn't support them
    if content_type&.match?(/heic|heif/i)
      image_data = convert_heic_to_jpeg(image_data)
      content_type = "image/jpeg"
    end

    ext = content_type == "image/png" ? "png" : "jpg"
    client = HandwritingOcr::Client.new
    doc_id = client.upload(image_data, filename: "page_#{page.page_number}.#{ext}", content_type: content_type)

    page.mark_ocr_submitted!(doc_id)

    # Start polling for this page
    PollOcrResultJob.set(wait: 2.seconds).perform_later(page_id)

  rescue HandwritingOcr::Error => e
    page.mark_failed!(e.message)
    check_job_failure(page.transcription_job)
  end

  private

  def convert_heic_to_jpeg(heic_data)
    Tempfile.create(["heic_input", ".heic"]) do |input|
      input.binmode
      input.write(heic_data)
      input.flush

      Tempfile.create(["jpeg_output", ".jpg"]) do |output|
        # Use ImageMagick convert with [0] to grab only the primary image,
        # skipping auxiliary references (HDR gain maps) that crash libheif
        system("convert", "#{input.path}[0]", "-quality", "90", output.path, exception: true)
        File.binread(output.path)
      end
    end
  end

  def check_job_failure(job)
    # If all pages have failed, mark the job as failed
    if job.job_pages.where(status: :failed).count == job.page_count
      job.mark_failed!("All pages failed to process")
    end
  end
end
