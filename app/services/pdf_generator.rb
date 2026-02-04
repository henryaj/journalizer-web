class PdfGenerator
  def initialize(entries)
    @entries = Array(entries)
  end

  def generate
    Prawn::Document.new(page_size: "A4", margin: 50) do |pdf|
      setup_fonts(pdf)

      @entries.each_with_index do |entry, index|
        pdf.start_new_page if index > 0
        render_entry(pdf, entry)
      end
    end.render
  end

  private

  def setup_fonts(pdf)
    pdf.font_size 11
    pdf.default_leading 4
  end

  def render_entry(pdf, entry)
    # Date header
    if entry.entry_date
      pdf.fill_color "666666"
      pdf.text entry.entry_date.strftime("%B %d, %Y"), size: 12
      pdf.move_down 5
      pdf.fill_color "000000"
    end

    # Title
    pdf.text entry.title, size: 18, style: :bold
    pdf.move_down 15

    # Content
    pdf.text entry.content, size: 11, leading: 4

    # Footer
    pdf.move_down 20
    pdf.stroke_color "cccccc"
    pdf.stroke_horizontal_rule
    pdf.move_down 10
    pdf.fill_color "888888"
    pdf.text "Transcribed with Journalizer on #{entry.created_at.strftime('%B %d, %Y')}", size: 9
    pdf.fill_color "000000"
  end
end
