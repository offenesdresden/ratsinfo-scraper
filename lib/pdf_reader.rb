require 'pdf-reader'

class PdfReader
  def initialize(pdf_path)
    @pdf_path = pdf_path
    @reader = PDF::Reader.new(@pdf_path)
  end

  def write_pages
    text_file_prefix = "#{File.dirname(@pdf_path)}/#{File.basename(@pdf_path, '.*')}"
    return if File.exists?(text_file_prefix + "_1.txt")

    begin
      @reader.pages.each_with_index do |page, i|
        text_file_path = "#{text_file_prefix}_#{i}.txt"
        file = File.open(text_file_path, "w+")
        file.puts(page.text)
        file.close
      end
    rescue PDF::Reader::MalformedPDFError => e
      puts "Skipping malformed PDF '#{@pdf_path}'"
      puts e.message
    end
  end

  def metadata
    info = @reader.info
    return unless info

    PdfMetadata.from_pdf_reader(@reader)
  end
end
