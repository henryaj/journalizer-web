class ObsidianExporter
  class ConfigError < StandardError; end

  def self.export_all(entries)
    new.export_all(entries)
  end

  def initialize
    @vault_path = ENV.fetch("OBSIDIAN_VAULT_PATH") { raise ConfigError, "OBSIDIAN_VAULT_PATH not set" }
    @journal_folder = ENV.fetch("OBSIDIAN_JOURNAL_FOLDER", "Journal")
  end

  def export_all(entries)
    entries.each { |entry| export(entry) }
  end

  def export(entry)
    FileUtils.mkdir_p(journal_dir)

    write_markdown(entry)
    copy_images(entry)

    Rails.logger.info "ObsidianExporter: wrote #{filename(entry)} to #{journal_dir}"
  end

  private

  def journal_dir
    File.join(@vault_path, @journal_folder)
  end

  def filename(entry)
    date = entry.entry_date&.iso8601 || entry.created_at.strftime("%Y-%m-%d")
    "#{date}.md"
  end

  def sanitize_filename(name)
    name.gsub(/[\/\\:*?"<>|]/, "-").strip.truncate(100, omission: "")
  end

  def write_markdown(entry)
    path = File.join(journal_dir, filename(entry))
    File.write(path, entry.to_markdown)
  end

  def copy_images(entry)
    date_prefix = entry.entry_date&.iso8601 || entry.created_at.strftime("%Y%m%d%H%M%S")

    entry.images.each_with_index do |image, i|
      image_filename = "journal-#{date_prefix}-#{i.to_s.rjust(3, '0')}.jpg"
      image_path = File.join(journal_dir, image_filename)

      image.open do |tempfile|
        vips_image = Vips::Image.new_from_file(tempfile.path)
        vips_image.jpegsave(image_path, Q: 85)
      end
    end
  end
end
