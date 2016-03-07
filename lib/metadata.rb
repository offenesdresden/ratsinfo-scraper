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

  def save_to(path)
    FileUtils.mkdir_p ::File.dirname(path)

    old = nil
    if ::File.exist? path
      old = self.class.load_from(path)
      # Retain old values
      merge! old do |key, value, old_value|
        if value.nil?
          # Overwrite new nil with old value
          old_value
        elsif not old_value.nil?
          # Old was nil
          value
        elsif old_value == value
          value
        else
          puts "Overwriting #{key}: #{old_value.inspect} to #{value.inspect}"
          value
        end
      end
    end

    if old != self
      # Changed, update
      json = JSON.pretty_generate(self)
      puts "Saving to #{path}"
      file = open(path, "w")
      file.write(json)
      file.close
    end
  end

  def self.load_from(path)
    json = JSON.load(::File.read(path))
    self.new(json)
  end
end

class Organization < OParlEntity
end

class Meeting < OParlEntity
  property :session_url
  property :name
  property :organization
  property :start, with: Proc.new { |v| Time.parse(v) }
  property :end, with: Proc.new { |v| Time.parse(v) }
  property :locality
  property :agendaItem, with: Proc.new{ |ary| ary.map { |v| AgendaItem.new(v) } }
  property :invitation
  property :resultsProtocol
  property :verbatimProtocol
  property :auxiliaryFile
  property :participant

  attr_accessor :files
  attr_accessor :persons

  def initialize(*a)
    super

    self.files = []
  end

  def self.load_from(path)
    this = super(path)
    this.agendaItem = this.agendaItem.map { |v| AgendaItem.new(v) }
    this
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
  property :number
  property :resolutionFile
  property :resolutionText
  property :auxiliaryFile

  attr_accessor :files
end

class File < OParlEntity
  property :fileName
  property :downloadUrl
  property :sha1Checksum
  property :size
  property :mimeType
end

class Person < OParlEntity
  property :membership
end

class Membership < OParlEntity
  property :organization
  property :role
  property :votingRight
  property :startDate
  property :endDate
  property :onBehalfOf
end

class Paper < OParlEntity
  property :reference
  property :publishedDate
  property :paperType

  attr_accessor :files
  property :mainFile
  property :auxiliaryFile

  property :consultation
end

class Consultation < OParlEntity
  property :meeting
  property :organization
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
