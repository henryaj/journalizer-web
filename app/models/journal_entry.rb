class JournalEntry < ApplicationRecord
  belongs_to :user
  belongs_to :transcription_job, optional: true
  has_many_attached :images

  validates :title, presence: true
  validates :content, presence: true

  scope :recent, -> { order(Arel.sql("COALESCE(entry_date, created_at::date) DESC")) }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :not_expired, -> { where("expires_at > ?", Time.current) }
  scope :unsynced, -> { where(synced: false) }

  after_create :set_expiration

  def to_markdown
    frontmatter_lines = [ "---" ]
    frontmatter_lines << "date: #{entry_date.iso8601}" if entry_date.present?
    frontmatter_lines << "type: journal"
    frontmatter_lines << "source: #{source}"
    frontmatter_lines << "imported_at: #{created_at.iso8601}"
    frontmatter_lines << "---"
    frontmatter = frontmatter_lines.join("\n")

    date_prefix = entry_date&.iso8601 || created_at.strftime("%Y%m%d%H%M%S")
    image_embeds = images.map.with_index do |img, i|
      "![[journal-#{date_prefix}-#{i.to_s.rjust(3, '0')}.jpg]]"
    end.join("\n")

    [
      frontmatter,
      "",
      "# #{title}",
      "",
      content,
      "",
      "---",
      "",
      "*Transcribed with [Journalizer](https://journalizer.me) on #{created_at.strftime("%B %d, %Y")}*",
      "",
      image_embeds
    ].join("\n")
  end

  def mark_synced!
    update!(synced: true)
  end

  def days_until_expiry
    return nil unless expires_at
    ((expires_at - Time.current) / 1.day).ceil
  end

  def expiry_urgency
    days = days_until_expiry
    return :expired if days.nil? || days <= 0
    return :critical if days <= 7
    return :warning if days <= 14
    :ok
  end

  private

  def set_expiration
    update_column(:expires_at, 30.days.from_now)
  end
end
