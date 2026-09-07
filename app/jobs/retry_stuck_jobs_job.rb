class RetryStuckJobsJob < ApplicationJob
  queue_as :default

  STUCK_THRESHOLD = 30.minutes

  def perform
    retried_count = 0

    # Find jobs stuck in processing states
    stuck_jobs = TranscriptionJob
      .where(status: %w[uploading processing post_processing])
      .where("updated_at < ?", STUCK_THRESHOLD.ago)

    stuck_jobs.find_each do |job|
      case job.status
      when "uploading"
        # Pages left mid-upload by a killed worker. Nothing else ever revisits
        # them, so the whole job sits in uploading forever.
        job.job_pages.upload_interrupted.where("updated_at < ?", STUCK_THRESHOLD.ago).find_each do |page|
          UploadToOcrJob.perform_later(page.id)
          Rails.logger.info "RetryStuckJobsJob: Re-enqueued UploadToOcrJob for page #{page.id} (upload interrupted)"
        end
        CheckOcrProgressJob.perform_later(job.id)

      when "processing"
        # Re-check OCR progress - this will either continue polling or trigger post-processing
        CheckOcrProgressJob.perform_later(job.id)
        Rails.logger.info "RetryStuckJobsJob: Re-enqueued CheckOcrProgressJob for job #{job.id} (stuck in processing)"

      when "post_processing"
        # Retry post-processing with Claude
        PostProcessJob.perform_later(job.id)
        Rails.logger.info "RetryStuckJobsJob: Re-enqueued PostProcessJob for job #{job.id} (stuck in post_processing)"
      end

      # Retries don't change any of the job's own columns, so without this the
      # next run 15 minutes later re-enqueues everything again while the first
      # attempt is often still sitting in the queue.
      job.touch

      retried_count += 1
    end

    Rails.logger.info "RetryStuckJobsJob: Retried #{retried_count} stuck jobs" if retried_count > 0
  end
end
