class ClaudePostProcessor
  ENTRY_TOOL = {
    name: "submit_entries",
    description: "Submit the processed journal entries",
    input_schema: {
      type: "object",
      properties: {
        entries: {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string", description: "Brief title (3-8 words) summarizing the entry" },
              text: { type: "string", description: "The cleaned journal entry text" },
              date: { type: ["string", "null"], description: "Date in YYYY-MM-DD format, or null if not found" },
              image_indices: {
                type: "array",
                items: { type: "integer" },
                description: "0-indexed page numbers this entry spans"
              }
            },
            required: ["title", "text", "date", "image_indices"]
          }
        }
      },
      required: ["entries"]
    }
  }.freeze

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

    Use the submit_entries tool to return the processed entries.
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
    6. Set image_indices to %{image_indices}

    Use the submit_entries tool to return the processed entry.
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
      max_tokens: 16384,
      tools: [ENTRY_TOOL],
      tool_choice: { type: "tool", name: "submit_entries" },
      messages: [{
        role: "user",
        content: "#{prompt}\n\nRaw OCR text:\n#{raw_text}"
      }]
    )

    parse_tool_response(response, page_count: page_count)
  end

  private

  def parse_tool_response(response, page_count:)
    # SDK returns :tool_use symbol, not "tool_use" string
    tool_use = response.content.find { |block| block.type.to_s == "tool_use" }

    unless tool_use
      Rails.logger.error "ClaudePostProcessor: No tool_use in response. Content types: #{response.content.map(&:type)}"
      return fallback_entry(page_count)
    end

    # SDK returns hash with symbol keys
    entries = tool_use.input[:entries] || tool_use.input["entries"]
    unless entries.is_a?(Array) && entries.any?
      Rails.logger.error "ClaudePostProcessor: Invalid entries in tool response: #{tool_use.input.inspect}"
      return fallback_entry(page_count)
    end

    entries.map do |entry|
      # Handle both symbol and string keys
      {
        title: (entry[:title] || entry["title"]) || "Journal Entry",
        text: entry[:text] || entry["text"],
        date: parse_date(entry[:date] || entry["date"]),
        image_indices: entry[:image_indices] || entry["image_indices"] || []
      }
    end
  rescue => e
    Rails.logger.error "ClaudePostProcessor: Error parsing tool response: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    fallback_entry(page_count)
  end

  def fallback_entry(page_count)
    [{
      title: "Journal Entry",
      text: "Error processing entry",
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
