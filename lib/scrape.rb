require 'json'
require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'mechanize'
require 'zip/zip'
require 'date'

require 'pry'

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

    return archive
  end

  class DocumentArchive
    def initialize(file_path)
      @zip_file = Zip::ZipFile.open(file_path)
      @metadata = parse_metadata(index_file)
      @metadata[:downloaded_at] = Time.now
    end

    attr_reader :metadata

    def extract(path)
      @zip_file.entries.each do |entry|
        entry.extract(File.join(path, entry.name))
      end
    end

    def as_json
      @metadata.clone
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
      content_rows = doc.css("table#smc_page_to0040_contenttable1 tbody tr.smcrow1")
      document_links = doc.css("body > table.smcdocbox tbody a.smcdoccontrol1")

      session = parse_session_description(desc_rows)
      parts = parse_parts_rows(content_rows)
      session[:parts] = parts
      session[:documents] = document_links.map do |link|
         { file_name: link["href"], description: link["title"].strip_whitespace }
      end
      session
    end

    def parse_session_description(rows)
      first_row = rows[0].css("td")
      id = first_row[1].text
      committee = first_row[3].text

      second_row = rows[1].css("td")
      date = second_row[1].text
      (start_time, end_time) = second_row[3].text.split("-")
      started_at = Time.parse(date + " " + start_time + " CEST")
      ended_at = Time.parse(date + " " + end_time + " CEST" )

      third_row = rows[2].css("td")
      if third_row[0].text.include?("Bezeichnung:") # location row is missing
        description = third_row[1].text
      else
        location = third_row[1].text.strip_whitespace
        forth_row = rows[3].css("td")
        description = forth_row[1].text
      end

      {
        id: id,
        description: description.strip_whitespace,
        committee: committee.strip_whitespace,
        started_at: started_at,
        ended_at: ended_at,
        location: location
      }
    end

    def parse_parts_rows(content_rows)
      grouped_rows = group_content_rows(content_rows)

      parts = grouped_rows.map do |rows|
        first_row = rows[0].css("td")
        description = first_row[1].text.strip_whitespace
        template_id = first_row[2].text
        if template_id.empty?
          template_id = nil
        end
        document_table = first_row[4]
        documents = []
        if document_table
          document_links = document_table.css("table tbody tr a")
          documents = document_links.map do |link|
            title = link["title"].strip_whitespace
            href = link["href"]
            { description: title.strip_whitespace, file_name: href }
          end
        end

        decision = nil
        if rows[1]
          decision = rows[1].css("td")[2].text
        end
        vote_result = nil
        if rows[2]
          cell = rows[2].css("td")[2]
          vote_result =  parse_vote(cell.text)
        end

        {
          description: description,
          template_id: template_id,
          documents: documents,
          decision: decision,
          vote_result: vote_result
        }
      end

      parts
    end
    def group_content_rows(rows)
      groups = []
      i = -1
      rows.each do |row|
        if row["id"] && row["id"].include?("smc_contol_to")
          i += 1
          groups[i] = []
        end
        groups[i] << row
      end
      groups
    end
    def parse_vote(text)
      result = {
        pro: 0,
        contra: 0,
        abstention: 0
      }
      text = text.strip_whitespace
      parts = text.split(", ")
      parts.each do |part|
        (type, number) = part.split(":")
        case type
        when "Ja"
          result[:pro] = number
        when "Nein"
          result[:contra] = number
        when "Enthaltung"
          result[:abstention] = number
        end
      end
      return result
    end
  end
end
