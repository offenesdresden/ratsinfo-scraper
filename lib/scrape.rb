require 'json'
require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'mechanize'
require 'pry'
require 'zip'
require 'date'
require 'tempfile'
require_relative 'metadata.rb'
require_relative 'pdf_reader.rb'

module Scrape
  # Base for all exception
  class ScrapeException < Exception
  end

  class ::Time
    def to_json(options={})
      utc.iso8601.to_json
    end
  end
  class ::String
    # remove in addition to builtin strip also Non-Breaking Space
    def strip_whitespace
      gsub(/\A[[:space:]]+|[[:space:]]+\z/, '')
    end
  end

  # Parse the session calendar and yield those session ids containing documents
  class ConferenceCalendarScraper
    include Enumerable
    def initialize(scrape_url)
      @scrape_url = scrape_url
    end
    include Enumerable

    def each(&block)
      doc = Nokogiri::HTML(open(@scrape_url))
      doc.css("table.smccontenttable tr").each do |row|
        conference_id = parse_row(row)
        yield conference_id unless conference_id.nil?
      end
    end

    private
    def parse_row(row)
      doc_cell = row.css(".smcdocbox").first
      return if doc_cell == nil
      conference_link = row.xpath("./td[6]/a").first
      if conference_link.nil?
        print("WARNING session_link not found")
        return
      end
      query = CGI.parse(conference_link["href"])
      id = query["to0040.php?__ksinr"].first
      id
    end
  end

  def self.download_zip_archive(conference_uri)
    agent = Mechanize.new
    page = agent.get(conference_uri)
    link = page.parser.css(".smcdocboxzip td a").first

    archive = Tempfile.new("ratsinfo")
    agent.pluggable_parser.default = Mechanize::Download
    agent.get(link["href"]).save!(archive.path)

    archive
  end

  def self.scrape_session(session_url, session_path)
    begin
      tmp_file = Scrape.download_zip_archive(session_url)

      archive = Scrape::DocumentArchive.new(tmp_file.path)
      archive.extract(session_path)
      metadata = archive.metadata
      metadata.session_url = session_url

      metadata.each_document do |doc|
        pdf_path = File.join(session_path, doc.file_name)
        next unless pdf_path.end_with?(".pdf")

        p = PdfReader.new(pdf_path)
        p.write_pages
        doc.pdf_metadata = p.metadata
      end
      json = JSON.pretty_generate(metadata)

      metadata_path = File.join(session_path, "metadata.json")
      metadata_file = open(metadata_path, "w+")
      metadata_file.write(json)
    rescue SignalException => e
      raise e
    rescue Exception => e
      puts e.message
      puts e.backtrace
      FileUtils.rm_rf(session_path)
    ensure
      tmp_file.unlink if tmp_file
    end
  end

  class DocumentArchive
    def initialize(file_path)
      @zip_file = Zip::File.open(file_path)
      @metadata = parse_metadata(index_file)
    end

    attr_reader :metadata

    def extract(path)
      @zip_file.entries.each do |entry|
        entry.extract(File.join(path, entry.name))
      end
    end

    private
    def index_file
      @zip_file.entries.each do |entry|
        # index file naming: index_20130713_0839.htm
        if entry.name =~ /index_.+\.htm/
          return entry.get_input_stream
        end
      end
      raise ScrapeException.new("no index.htm found in archive")
    end

    def parse_metadata(index_file)
      doc = Nokogiri::HTML(index_file)
      desc_rows = doc.css("table#smctablevorgang tbody tr")
      content_rows = doc.xpath("//table[@id='smc_page_to0040_contenttable1']/tbody/tr[not(@class='smcrowh')]")
      document_links = doc.css("body > table.smcdocbox tbody td:not(.smcdocname) a")

      metadata = parse_session_description(desc_rows)
      metadata.parts = parse_parts_rows(group_content_rows(content_rows))
      metadata.documents = parse_documents_table(document_links)
      metadata.downloaded_at = Time.now
      metadata
    end

    def parse_session_description(rows)
      first_row = rows[0].css("td")
      id = first_row[1].text
      committee = first_row[3].text

      second_row = rows[1].css("td")
      date = second_row[1].text
      (start_time, end_time) = second_row[3].text.split("-")
      started_at = Time.parse(date + " " + start_time + " CEST")
      ended_at = nil
      unless end_time.nil? # end time can be omitted
        ended_at = Time.parse(date + " " + end_time + " CEST" )
      end

      third_row = rows[2].css("td")
      if third_row[0].text.include?("Bezeichnung:") # location row is missing
        description = third_row[1].text
      else
        location = third_row[1].text.strip_whitespace
        forth_row = rows[3].css("td")
        description = forth_row[1].text
      end

      m = Metadata.new
      m.id = id
      m.description = description.strip_whitespace
      m.committee = committee.strip_whitespace
      m.started_at = started_at
      m.ended_at = ended_at
      m.location = location
      m
    end

    def parse_parts_rows(grouped_rows)
      parts = grouped_rows.map do |rows|
        first_row = rows[0]
        first_row[1].css("br").each{ |br| br.replace "\n" }
        description = first_row[1].text.strip_whitespace
        template_id = first_row[2].text.strip_whitespace

        if template_id.empty?
          template_id = nil
        end

        document_table = first_row[4]
        if document_table
          document_links = document_table.css("table tbody tr td:not(.smcdocname) a")
          documents = parse_documents_table(document_links)
        end

        if rows[1]
          decision = rows[1].css("td")[2].text
        end
        if rows[2]
          cell = rows[2].css("td")[2]
          vote_result =  parse_vote(cell.text)
        end

        p = Part.new
        p.description = description
        p.template_id = template_id
        p.documents = documents
        p.decision = decision
        p.vote_result = vote_result
        p
      end

      parts
    end

    def parse_documents_table(links)
      links.map do |link|
        d = Document.new
        d.file_name = link["href"]
        d.description = link["title"].strip_whitespace
        d
      end
    end

    def group_content_rows(rows)
      groups = []
      i = -1
      rows.each do |row|
        columns = row.children
        # every new part begins with a new number in the first column
        if is_number?(columns[0].text)
          i += 1
          groups[i] = []
        end
        # skip garbage before our real parts begins
        if i >= 0
          groups[i] << columns
        end
      end
      groups
    end

    def is_number?(i)
      true if Float(i) rescue false
    end

    def parse_vote(text)
      result = VoteResult.new
      text = text.strip_whitespace
      parts = text.split(", ")
      parts.each do |part|
        (type, number) = part.split(":")
        number = Integer(number.strip_whitespace) rescue 0
        case type.strip_whitespace
        when "Ja"
          result.pro = number
        when "Nein"
          result.contra = number
        when "Enthaltungen"
          result.abstention = number
        when "Befangen"
          result.prejudiced = number
        end
      end
      result
    end
  end
end
