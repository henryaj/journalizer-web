class ClaudePostProcessor
  BASE_PROMPT = <<~PROMPT.freeze
    You are processing OCR output from handwritten journal pages.

    The raw text may contain:
    - Page headers (e.g., "DATUM/DATE", "DATE") - remove these
    - Page numbers at the bottom - remove these
    - Multiple dated entries from different days - split into separate entries
    - Page markers like "--- Page 0 ---" - use these to track image indices

    Instructions:
    1. Remove any page headers and page numbers
    2. Look for dates in any format (e.g., "Thursday, December 25", "Dec 28", "25/12/24")
    3. If there are multiple dated entries, split them
    4. Track which page(s) each entry spans (0-indexed)
    5. Convert dates to ISO format (YYYY-MM-DD).%{year_instruction}
    6. Generate a brief title (3-8 words) summarizing the entry's main theme or topic

    Output JSON:
    {
      "entries": [
        {
          "title": "Brief summary of the entry",
          "text": "The cleaned text...",
          "date": "2024-12-25" or null if no date found,
          "image_indices": [0] or [0, 1]
        }
      ]
    }

    Only output JSON, no other text.
  PROMPT

  SINGLE_ENTRY_PROMPT = <<~PROMPT.freeze
    You are processing OCR output from handwritten journal pages that should be treated as a SINGLE entry.

    The raw text may contain:
    - Page headers (e.g., "DATUM/DATE", "DATE") - remove these
    - Page numbers at the bottom - remove these
    - Page markers like "--- Page 0 ---" - remove these

    Instructions:
    1. Remove any page headers, page numbers, and page markers
    2. Look for a date in any format (e.g., "Thursday, December 25", "Dec 28", "25/12/24")
    3. Combine ALL text into ONE entry (do NOT split even if multiple dates are found)
    4. Convert the first/main date to ISO format (YYYY-MM-DD).%{year_instruction}
    5. Generate a brief title (3-8 words) summarizing the entry's main theme or topic

    Output JSON:
    {
      "entries": [
        {
          "title": "Brief summary of the entry",
          "text": "The cleaned, combined text...",
          "date": "2024-12-25" or null if no date found,
          "image_indices": %{image_indices}
        }
      ]
    }

    Only output JSON, no other text.
  PROMPT

  def initialize(api_key: nil)
    @api_key = api_key || ENV.fetch("ANTHROPIC_API_KEY")
  end

  def process(raw_text, page_count:, year_hint: nil, force_single_entry: false)
    client = Anthropic::Client.new(api_key: @api_key)

    year_instruction = if year_hint.present?
      " Use #{year_hint} as the year for all dates (the user specified these entries are from #{year_hint})."
    else
      " Infer the year from context (assume recent past if ambiguous)."
    end

    prompt = if force_single_entry
      image_indices = (0...page_count).to_a.to_s
      SINGLE_ENTRY_PROMPT % { year_instruction: year_instruction, image_indices: image_indices }
    else
      BASE_PROMPT % { year_instruction: year_instruction }
    end

    response = client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 4096,
      messages: [{
        role: "user",
        content: "#{prompt}\n\nRaw OCR text:\n#{raw_text}"
      }]
    )

    parse_response(response.content.first.text, page_count: page_count)
  end

  private

  def parse_response(text, page_count:)
    # Try to extract JSON from response
    json_match = text.match(/\{[\s\S]*\}/)
    unless json_match
      return [{
        title: "Journal Entry",
        text: text.strip,
        date: nil,
        image_indices: (0...page_count).to_a
      }]
    end

    data = JSON.parse(json_match[0])

    data["entries"].map do |entry|
      {
        title: entry["title"] || "Journal Entry",
        text: entry["text"],
        date: parse_date(entry["date"]),
        image_indices: entry["image_indices"] || []
      }
    end
  rescue JSON::ParserError
    [{
      title: "Journal Entry",
      text: text.strip,
      date: nil,
      image_indices: (0...page_count).to_a
    }]
  end

  def parse_date(date_str)
    return nil if date_str.blank?
    Date.parse(date_str)
  rescue ArgumentError
    nil
  end
end
