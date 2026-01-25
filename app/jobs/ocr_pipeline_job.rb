class OcrPipelineJob < ApplicationJob
  queue_as :default

  def perform(job_id)
    job = TranscriptionJob.find(job_id)
    return if job.completed? || job.failed?

    job.mark_started!

    # Enqueue upload jobs for each page (staggered for rate limiting)
    # HandwritingOCR allows 2 req/sec, so stagger by 600ms
    job.job_pages.in_order.each_with_index do |page, index|
      UploadToOcrJob.set(wait: (index * 0.6).seconds).perform_later(page.id)
    end

    # Schedule a check for when all uploads should be done
    # Allow extra time for uploads + initial processing
    estimated_time = (job.page_count * 0.6 + 10).seconds
    CheckOcrProgressJob.set(wait: estimated_time).perform_later(job_id)
  end
end
