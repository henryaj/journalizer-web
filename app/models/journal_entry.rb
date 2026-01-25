class JournalEntry < ApplicationRecord
  belongs_to :user
  belongs_to :transcription_job, optional: true
  has_many_attached :images

  validates :entry_date, presence: true
  validates :content, presence: true

  scope :recent, -> { order(entry_date: :desc) }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :not_expired, -> { where("expires_at > ?", Time.current) }
  scope :unsynced, -> { where(synced: false) }

  after_create :set_expiration

  def to_markdown
    frontmatter = [
      "---",
      "date: #{entry_date.iso8601}",
      "type: journal",
      "source: #{source}",
      "---"
    ].join("\n")

    heading = entry_date.strftime("%B %d, %Y")

    image_embeds = images.map.with_index do |img, i|
      "![[journal-#{entry_date.iso8601}-#{i.to_s.rjust(3, '0')}.jpg]]"
    end.join("\n")

    [
      frontmatter,
      "",
      "# #{heading}",
      "",
      content,
      "",
      "---",
      "",
      "*Transcribed from handwritten entry*",
      "",
      image_embeds
    ].join("\n")
  end

  def mark_synced!
    update!(synced: true)
  end

  private

  def set_expiration
    update_column(:expires_at, 30.days.from_now)
  end
end
