class CheckOcrProgressJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(job_id)
    job = TranscriptionJob.find(job_id)
    return if job.completed? || job.failed?

    # Check if all pages have reached terminal state
    pending_pages = job.job_pages.where.not(status: [:ocr_complete, :failed])

    if pending_pages.any?
      # Some pages still processing - check again later
      CheckOcrProgressJob.set(wait: 30.seconds).perform_later(job_id)
    else
      # All pages done - if there are completed pages, trigger post-processing
      completed_pages = job.job_pages.where(status: :ocr_complete)

      if completed_pages.any?
        # PostProcessJob will be triggered by PollOcrResultJob when the last page completes
        # This is a safety check in case the normal flow didn't trigger it
        unless job.post_processing? || job.completed?
          PostProcessJob.perform_later(job_id)
        end
      else
        job.mark_failed!("No pages completed successfully")
      end
    end
  end
end
