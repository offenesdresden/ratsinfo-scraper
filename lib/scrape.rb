require 'json'
require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'mechanize'
require 'pry'
require 'zip'
require 'date'
require 'tempfile'
require 'stringio'
require_relative 'metadata.rb'
require_relative 'tika_app.rb'

module Scrape

  def self.download_zip_archive(conference_uri)
    agent = Mechanize.new
    page = agent.get(conference_uri)
    documents = page.parser.css(".smcdocbox td.smc_doc")
    if documents.size < 1
      return :no_documents
    end
    link = page.parser.css(".smcdocboxzip td a").first

    archive = Tempfile.new("ratsinfo")
    agent.pluggable_parser.default = Mechanize::Download
    agent.get(link["href"]).save!(archive.path)

    archive
  end


  def self.scrape_session(session_url, session_path)
    begin
      tmp_file = Scrape.download_zip_archive(session_url)
      if tmp_file == :no_documents
         puts "no documents found at #{session_url}"
        return
      end

      archive = Scrape::DocumentArchive.new(tmp_file.path, session_url)
      archive.extract(session_path)
      meeting = archive.meeting

      meeting.each_document do |doc|
        pdf_path = File.join(session_path, doc.fileName)
        next unless pdf_path.end_with?(".pdf")
            tika = TikaApp.new(pdf_path)

            xmlfile_path = pdf_path.sub('.pdf','.xml')
            xmlfile = open(xmlfile_path, "w+")
            xmlfile.write(tika.get_xml)

=begin
            filter = JSON.load(tika.get_metadata)
            hs = {
                "Content-Length" => filter["Content-Type"],
                "Content-Type" => filter["Content-Type"],
                "Creation-Date" => filter["Creation-Date"],
                "Last-Modified" => filter["Last-Modified"],
                "Author" => filter["Author"]
                }
            doc.pdf_metadata = hs
=end
      end

      json = JSON.pretty_generate(meeting)

      meeting_file = open(File.join(session_path, "meeting.json"), "w+")
      meeting_file.write(json)

      return :ok
    rescue SignalException => e
      raise e
    rescue Exception => e
      puts e.message
      puts e.backtrace
      FileUtils.rm_rf(session_path)
    ensure
      tmp_file.unlink if tmp_file.is_a? File
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


  class DocumentArchive
    def initialize(file_path, meeting_url)
      @zip_file = Zip::File.open(file_path)
      @meeting = parse_meeting(index_file, meeting_url)
    end

    attr_reader :meeting

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
      raise Exception.new("no index.htm found in archive")
    end

    def parse_meeting(index_file, meeting_url)
      doc = Nokogiri::HTML(index_file)
      desc_rows = doc.css("table#smctablevorgang tbody tr")
      content_rows = doc.xpath("//table[@id='smc_page_to0040_contenttable1']/tbody/tr[not(@class='smcrowh')]")
      document_links = doc.css("body > table.smcdocbox tbody td:not(.smcdocname) a")

      meeting = parse_meeting_description(desc_rows)
      meeting.id = meeting_url
      meeting.agendaItem = parse_agenda_rows(group_content_rows(content_rows))
      meeting.participant = parse_participants(meeting_url)
      files = parse_files_table(document_links)
      meeting.auxiliaryFile = files.select do |file|
        case file.name
        when /einladung/i
          if meeting.invitation
          then true
          else
            meeting.invitation = file
            false
          end
        when /niederschrift/i
          if meeting.verbatimProtocol
          then true
          else
            meeting.verbatimProtocol = file
            false
          end
        when /beschlussausfertigung/i, /ergebnisprotokoll/i
          if meeting.resultsProtocol
          then true
          else
            meeting.resultsProtocol = file
            false
          end
        else
          # auxiliaryFile
          true
        end
      end
      meeting.downloaded_at = Time.now
      meeting
    end

    def parse_meeting_description(rows)
      first_row = rows[0].css("td")
      short_name = first_row[1].text
      organization = first_row[3].text

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
        name = third_row[1].text
      else
        locality = third_row[1].text.strip_whitespace
        forth_row = rows[3].css("td")
        name = forth_row[1].text
      end

      meeting = OParl::Meeting.new
      meeting.id = nil
      meeting.shortName = short_name
      meeting.name = name.strip_whitespace
      meeting.organization = [organization.strip_whitespace]
      meeting.start = started_at
      meeting.end = ended_at
      meeting.locality = locality
      meeting
    end

    def parse_participants(meeting_url)
      participant_url = meeting_url.gsub! '/to0040.php', '/to0045.php'
      participants = Array.new()
      doc = Nokogiri::HTML(open(participant_url))
      doc.css("table.smccontenttable tr").each do |row|
        participant = row.css("td a")
        if participant.to_s != ''
          name = participant.attr('title').to_s()[18..-1]
          itsUrl = row.css("td a").attr('href').to_s()
          participants.push(
            OParl::Person.new(
            { :id => itsUrl,
              :name => name.strip_whitespace
            })
          )
        end
      end
      participants
    end

    def parse_agenda_rows(grouped_rows)
       grouped_rows.map do |rows|
        first_row = rows[0]
        first_row[2].css("br").each{ |br| br.replace "\n" }
        description = first_row[2].text.strip_whitespace
        template_id = first_row[3].text.strip_whitespace

        number = first_row[1].text

        if template_id.empty?
          template_id = nil
        end

        document_table = first_row[5]
        if document_table
          document_links = document_table.css("table tbody tr td:not(.smcdocname) a")
          files = parse_files_table(document_links)
        end

        if rows[1]
          decision = rows[1].css("td")[2].text
        end
        if rows[2]
          cell = rows[2].css("td")[2]
          vote_result = parse_vote(cell.text)
        end

        OParl::AgendaItem.new(
          { :name => description,
            :consultation => template_id,
            :number => number,
            :auxiliaryFile => files
          })
        # TODO: deal with decision, vote_result
      end
    end

    def parse_files_table(links)
      links.map do |link|
        f = OParl::File.new
        f.fileName = link["href"]
        f.name = link["title"].strip_whitespace
        f
      end
    end

    def group_content_rows(rows)
      groups = []
      i = -1
      rows.each do |row|
        columns = row.children
        # every new part begins with a new number in the first column
        if is_number?(columns[1].text)
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
      res = false
      res = true if i =~ /^\d+\.\d/ rescue false #findet float am Anfang -> https://github.com/offenesdresden/ratsinfo-scraper/issues/13
      res = true if Float(i) rescue false
      res
    end

    def parse_vote(text)
      result = OParl::VoteResult.new
      text = text.strip_whitespace
      parts = text.split(", ")
      parts.each do |part|
        (type, number) = part.split(":")
        number = Integer(number.strip_whitespace) rescue 0
        case type.strip_whitespace
        when "Ja"
          result.yes = number
        when "Nein"
          result.no = number
        when "Enthaltungen"
          result.neutral = number
        when "Befangen"
          result.biased = number
        end
      end
      result
    end
  end
end
