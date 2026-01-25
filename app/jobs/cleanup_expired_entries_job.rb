class CleanupExpiredEntriesJob < ApplicationJob
  queue_as :default

  def perform
    count = 0

    JournalEntry.expired.find_each do |entry|
      # Purge attached images from storage
      entry.images.purge
      entry.destroy
      count += 1
    end

    Rails.logger.info "Cleaned up #{count} expired journal entries"
  end
end
