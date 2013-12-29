require 'hashie'

class Metadata < Hashie::Trash
  property :id
  property :session_url
  property :description
  property :committee
  property :started_at, with: Proc.new { |v| Time.parse(v) }
  property :ended_at, with: Proc.new { |v| Time.parse(v) }
  property :location
  property :downloaded_at, with: Proc.new { |v| Time.parse(v) }
  property :documents, with: Proc.new{ |ary| ary.map { |v| Document.new(v) } }
  property :parts, with: Proc.new{ |ary| ary.map { |v| Part.new(v) } }

  def each_document(&block)
    documents.each &block
    parts.each {|p| p.documents.each block }
  end
end

class Document < Hashie::Trash
  property :file_name
  property :description
  property :pdf_metadata
  property :raw_classifications
end

class PdfMetadata < Hashie::Trash
  LatinToUtf8Converter = Encoding::Converter.new("ISO-8859-1", "utf-8")

  property :created_at, with: Proc.new { |v| Time.parse(v) }
  property :updated_at, with: Proc.new { |v| Time.parse(v) } # :modification_date
  property :author, with: Proc.new { |v| Time.parse(v) }
  property :creator
  property :producer
  property :page_count, with: Proc.new { |v| v.to_i }
  property :pdf_title
  property :keywords

  def self.from_pdf_reader(reader)
    info = reader.info
    new(
      created_at: parse_pdf_date(info[:CreationDate]),
      updated_at: parse_pdf_date(info[:ModDate]),
      author: guess_encoding(info[:Author]),
      creator: guess_encoding(info[:Creator]),
      producer: guess_encoding(info[:Producer]),
      page_count: reader.page_count,
      pdf_title: guess_encoding(info[:Title] || info["Subject"]),
      keywords: guess_encoding(info[:Keywords])
    )
  end

  private
  def self.parse_pdf_date(date)
    return if date.nil?
    date = date.sub("D:", "").sub("'", "")
    Time.parse(date)
  end

  def self.guess_encoding(str)
    return unless str
    if Kconv.isutf8(str)
      str
    else
      LatinToUtf8Converter.convert(str)
    end
  end
end

class Part < Hashie::Trash
  property :description
  property :template_id
  property :documents, with: Proc.new { |ary| ary.map { |v| Document.new(v) } }
  property :decision
  property :vote_result, with: Proc.new { |v| VoteResult.new(v) }
end

class VoteResult < Hashie::Trash
  property :pro, default: 0
  property :contra, default: 0
  property :abstention, default: 0
  property :prejudiced, default: 0
end
