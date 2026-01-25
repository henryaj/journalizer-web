class CleanupExpiredJobsJob < ApplicationJob
  queue_as :default

  def perform
    count = 0

    TranscriptionJob.expired.find_each do |job|
      # Purge all page images
      job.job_pages.each do |page|
        page.image.purge if page.image.attached?
      end

      job.destroy
      count += 1
    end

    Rails.logger.info "Cleaned up #{count} expired transcription jobs"
  end
end
