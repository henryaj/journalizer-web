class PollOcrResultJob < ApplicationJob
  queue_as :ocr_poll

  MAX_POLLS = 60  # ~5 minutes with backoff

  retry_on HandwritingOcr::RateLimitError, wait: 5.seconds, attempts: 10
  discard_on ActiveRecord::RecordNotFound

  def perform(page_id, poll_count: 0)
    page = JobPage.find(page_id)
    return unless page.ocr_submitted? || page.ocr_processing?

    page.mark_ocr_processing!

    client = HandwritingOcr::Client.new
    result = client.get_result(page.handwriting_ocr_doc_id)

    case result[:status]
    when :completed
      page.mark_ocr_complete!(result[:text])
      check_all_pages_complete(page.transcription_job)

    when :processing
      if poll_count >= MAX_POLLS
        page.mark_failed!("OCR timed out after #{MAX_POLLS} polls")
        return
      end

      # Exponential backoff: 2, 3, 4.5, 6.75... up to 30 seconds
      delay = [2 * (1.5 ** [poll_count, 10].min), 30].min.seconds

      PollOcrResultJob.set(wait: delay).perform_later(page_id, poll_count: poll_count + 1)

    when :failed
      page.mark_failed!(result[:error])
    end
  end

  private

  def check_all_pages_complete(job)
    pages = job.job_pages

    # If there are still pages not in terminal state, wait
    return if pages.where.not(status: [:ocr_complete, :failed]).exists?

    completed_pages = pages.where(status: :ocr_complete)

    if completed_pages.any?
      PostProcessJob.perform_later(job.id)
    else
      job.mark_failed!("No pages completed successfully")
    end
  end
end
