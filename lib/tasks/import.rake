namespace :journal do
  def import_cache(dir)
    path = File.join(Dir.tmpdir, "journal-import-#{Digest::SHA256.hexdigest(File.expand_path(dir))[0, 12]}")
    FileUtils.mkdir_p(path)
    path
  end

  def import_pages(dir)
    abort "no such directory: #{dir}" unless Dir.exist?(dir)
    images = Dir.glob(File.join(dir, "*.{jpg,jpeg,png,heic,webp,tif,tiff}"), File::FNM_CASEFOLD)
    abort "no images in #{dir}" if images.empty?
    # Zero-pad digit runs so page9 sorts before page10.
    images.sort_by { |f| File.basename(f).gsub(/\d+/) { |d| d.rjust(12, "0") } }
  end

  def import_vault
    vault = ENV.fetch("OBSIDIAN_VAULT_PATH")
    dirs = [ File.join(vault, ENV.fetch("OBSIDIAN_JOURNAL_FOLDER", "Journal")), File.join(vault, "attachments") ]
    dirs.each { |d| abort "no such directory: #{d}" unless Dir.exist?(d) }
    dirs
  end

  desc "Step 1: OCR local photos. rake 'journal:ocr[/path/to/photos]'"
  task :ocr, [ :dir ] => :environment do |_t, args|
    dir = args[:dir] || abort("usage: rake 'journal:ocr[/path/to/photos]'")
    images = import_pages(dir)
    cache = import_cache(dir)
    client = HandwritingOcr::Client.new

    # Pages cache individually, so OCRing in chunks costs the same as one big run.
    todo = images
    if ENV["LIMIT"]
      todo = images.first(Integer(ENV["LIMIT"]))
      puts "LIMIT=#{ENV['LIMIT']}: first #{todo.size} of #{images.size} pages only"
    end

    puts "#{images.size} pages from #{dir}"
    puts "cache: #{cache} (delete a .txt to re-OCR that page)"

    todo.each_with_index do |src, i|
      jpg = File.join(cache, format("%03d.jpg", i))
      txt = File.join(cache, format("%03d.txt", i))
      next if File.exist?(txt)

      UploadToOcrJob.normalize(src, jpg) unless File.exist?(jpg)

      doc_id = File.open(jpg, "rb") { |io| client.upload(io, filename: format("page_%03d.jpg", i)) }
      print "page #{i} #{File.basename(src)} -> #{doc_id} "

      text = nil
      60.times do
        sleep 5
        result = client.get_result(doc_id)
        case result[:status]
        when :completed then text = result[:text]
        when :failed then abort "\npage #{i} failed: #{result[:error]}"
        else print "."
        end
        break if text
      end
      abort "\npage #{i} timed out after 5 minutes" unless text

      File.write(txt, text)
      puts "ok"
    end

    done = images.each_index.select { |i| File.exist?(File.join(cache, format("%03d.txt", i))) }
    puts "not yet OCRed, left out of combined.txt: #{images.each_index.to_a - done}" if done.size < images.size

    combined = done.map do |i|
      "--- Page #{i} (#{File.basename(images[i])}) ---\n#{File.read(File.join(cache, format('%03d.txt', i)))}"
    end.join("\n\n")

    File.write(File.join(cache, "combined.txt"), combined)
    puts "\nraw text: #{File.join(cache, 'combined.txt')}"
  end

  desc "Step 2: write structured entries into the vault. rake 'journal:write[/path/to/photos,entries.json]'"
  task :write, [ :dir, :entries ] => :environment do |_t, args|
    dir = args[:dir] || abort("usage: rake 'journal:write[/path/to/photos,entries.json]'")
    entries_path = args[:entries] || abort("usage: rake 'journal:write[/path/to/photos,entries.json]'")
    dry_run = ENV["DRY_RUN"].present?

    images = import_pages(dir)
    cache = import_cache(dir)
    journal_dir, attachments_dir = import_vault
    entries = JSON.parse(File.read(entries_path), symbolize_names: true)
    abort "#{entries_path}: expected a JSON array of entries" unless entries.is_a?(Array)

    entries.each_with_index do |entry, n|
      %i[title text date image_indices].each do |key|
        abort "entry #{n}: missing #{key}" if entry[key].nil? || entry[key] == ""
      end
      abort "entry #{n}: date must be YYYY-MM-DD, got #{entry[:date].inspect}" unless entry[:date].to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      abort "entry #{n}: image_indices must be a non-empty array" unless entry[:image_indices].is_a?(Array) && entry[:image_indices].any?
      entry[:image_indices].each do |i|
        abort "entry #{n}: no page #{i} (#{images.size} pages)" unless i.is_a?(Integer) && i.between?(0, images.size - 1)
        # Bail before any markdown is written rather than half way through the copies.
        abort "entry #{n}: page #{i} not in cache - run journal:ocr first" unless File.exist?(File.join(cache, format("%03d.jpg", i)))
      end
    end

    claimed = entries.flat_map { |e| e[:image_indices] }
    # A spread often ends one entry and starts the next, so both legitimately embed it.
    shared = claimed.tally.select { |_, c| c > 1 }.keys.sort
    puts "pages shared between entries (expected for continuations): #{shared}" if shared.any?
    missed = (0...images.size).to_a - claimed
    puts "warning: pages not claimed by any entry: #{missed}" if missed.any?

    puts "#{entries.size} entries#{dry_run ? ' (DRY RUN, nothing written)' : ''}"

    entries.each do |entry|
      stamp = entry[:date]

      md_path = File.join(journal_dir, "#{stamp}.md")
      if File.exist?(md_path)
        n = 2
        n += 1 while File.exist?(File.join(journal_dir, "#{stamp}-#{n}.md"))
        md_path = File.join(journal_dir, "#{stamp}-#{n}.md")
      end

      taken = Dir.glob(File.join(attachments_dir, "journal-#{stamp}-*.jpg")).map { |f| f[/-(\d+)\.jpg\z/, 1].to_i }
      first = taken.empty? ? 0 : taken.max + 1
      embeds = entry[:image_indices].each_index.map { |i| "journal-#{stamp}-#{format('%03d', first + i)}.jpg" }

      markdown = [
        "---",
        "date: #{stamp}",
        "type: journal",
        "source: handwritten-ocr",
        "imported_at: #{Time.current.utc.iso8601}",
        "---",
        "",
        "# #{entry[:title]}",
        "",
        entry[:text],
        "",
        "---",
        "",
        "*Transcribed with [Journalizer](https://journalizer.me) on #{Time.current.strftime('%B %d, %Y')}*",
        "",
        embeds.map { |e| "![[#{e}]]" }.join("\n")
      ].join("\n")

      if dry_run
        puts "  #{File.basename(md_path)}  #{entry[:title]}  pages #{entry[:image_indices].inspect} -> #{embeds.first}#{'..' if embeds.size > 1}"
      else
        File.write(md_path, markdown)
        entry[:image_indices].each_with_index do |page, i|
          FileUtils.cp(File.join(cache, format("%03d.jpg", page)), File.join(attachments_dir, embeds[i]))
        end
        puts "  wrote #{File.basename(md_path)}  #{entry[:title]}  (#{embeds.size} images)"
      end
    end
  end
end
