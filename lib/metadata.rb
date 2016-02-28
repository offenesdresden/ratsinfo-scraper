require 'hashie'

class ::Time
  def to_json(options={})
    utc.iso8601.to_json
  end
end

module OParl
##
# https://oparl.org/spezifikation/online-ansicht/#eigenschaften-mit-verwendung-in-mehreren-objekttypen
class OParlEntity < Hashie::Trash
  property :id
  property :type
  property :name
  property :shortName
  property :license
  property :created
  property :modified
  property :keyword
  property :parentID

  def initialize(*a)
    super

    self.type = "https://oparl.org/schema/1.0/#{self.class.name.split(/::/).last}"
  end
end

class Meeting < OParlEntity
  property :session_url
  property :name
  property :organization
  property :start, with: Proc.new { |v| Time.parse(v) }
  property :end, with: Proc.new { |v| Time.parse(v) }
  property :locality
  property :downloaded_at, with: Proc.new { |v| Time.parse(v) }
  property :agendaItem, with: Proc.new{ |ary| ary.map { |v| AgendaItem.new(v) } }
  property :resultsProtocol, with: Proc.new { |v| File.new(v) }
  property :verbatimProtocol, with: Proc.new { |v| File.new(v) }
  property :auxiliaryFile, with: Proc.new { |ary| ary.map { |v| File.new(v) } }
  property :participant

  def each_document(&block)
    block.call(resultsProtocol) if resultsProtocol
    auxiliaryFile.each(&block)
  end
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

class AgendaItem < OParlEntity
  property :consultation
end

class Consultation < OParlEntity
  property :meeting
end

class File < OParlEntity
  property :fileName
  property :consultation, with: Proc.new { |v| [Consultation.new(v)] }
end

class Participant < OParlEntity
    property :id
    property :Name
end



##
# Our invention!
class VoteResult < OParlEntity
  property :yes
  property :no
  property :neutral
  property :biased
end

end
