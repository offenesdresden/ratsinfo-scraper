# coding: utf-8
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
      archive.meeting
      
    rescue SignalException => e
      raise e
    rescue Exception => e
      puts e.message
      puts e.backtrace
      FileUtils.rm_rf(session_path)
      nil
    ensure
      tmp_file.unlink if tmp_file.is_a? File
    end
  end

  def self.write_json_file(path, content)
    FileUtils.mkdir_p File.dirname(path)

    json = JSON.pretty_generate(content)
    file = open(path, "w+")
    file.write(json)
    file.close
  end



  class ::String
    # remove in addition to builtin strip also Non-Breaking Space
    def strip_whitespace
      gsub(/\A[[:space:]]+|[[:space:]]+\z/, '')
    end
  end

  class VorlagenListeScraper
    include Enumerable

    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def each(&block)
      doc = Nokogiri::HTML(open(@scrape_url))
      doc.css("table.smccontenttable tr").each do |row|
        paper = parse_row(row)
        yield paper if paper
      end
    end

    private
    def parse_row(row)
      name = row.css('a.smc_field_voname')
      if name.empty?
        return nil
      end

      id = nil
      if name.attr('href').to_s =~ /kvonr=(\d+)/
        id = $1
      end

      long_name = name.text().strip_whitespace
      if name.attr('title').to_s =~ /^Vorlage anzeigen: (.+)$/
        long_name = $1.strip_whitespace
      end

      OParl::Paper.new(
        { :id => id,
          :name => long_name
        })
    end
  end

  class AnfragenListeScraper
    include Enumerable

    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def each(&block)
      doc = Nokogiri::HTML(open(@scrape_url))
      n = 0
      paper = nil
      doc.css("table.smccontenttable tr").each do |row|
        if n % 2 == 0
          paper = parse_row1(row)
        elsif paper
          parse_row2(row, paper)
          yield paper
        end

        n += 1
      end
    end

    private
    def parse_row1(row)
      name = row.css('a.smc_doc')
      if not name.empty? and
        (href = name.attr('href').to_s) and
        href =~ /kagnr=(\d+)/


        OParl::Paper.new(
          { :id => $1,
            :name => name.text().strip_whitespace
          })
      elsif href
        puts "Unexpected Anfrage: #{href}"
      end
    end

    def parse_row2(row, paper)
      smctd1 = row.css('.smctd1')
      paper.shortName = smctd1[0].text().strip_whitespace
      paper.publishedDate = Date.parse(row.css('.smc_field_agvdat').text()).iso8601
      paper.paperType = smctd1[1].text().strip_whitespace

      paper.files = []
      row.css('.smcdocname a').each do |row|
        if row.attr('href').to_s =~ /id=(\d+)/
          f = OParl::File.new(
            { :name => row.attr('title').to_s.strip_whitespace,
              :id => $1
            })
          paper.files << f
          if not paper.mainFile and f.name == paper.shortName
            paper.mainFile = f.id
          else
            paper.auxiliaryFile = [] unless paper.auxiliaryFile
            paper.auxiliaryFile << f.id
          end
        end
      end
    end
  end

  class PaperScraper
    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def scrape
      doc = Nokogiri::HTML(open(@scrape_url))

      vorgang = parse_vorgang(doc)
      paper = OParl::Paper.new(
        { :name => vorgang['Betreff'],
          :shortName => vorgang['Name'],
          :publishedDate => Date.parse(vorgang['Datum']).iso8601,
          :paperType => vorgang['Art']
        })

      paper.files = parse_files(doc)
      paper.files.each do |file|
        if file.name == vorgang['Name']
          paper.mainFile = file.id
        else
          paper.auxiliaryFile = [] unless paper.auxiliaryFile
          paper.auxiliaryFile.push(file.id)
        end
      end

      paper.consultation = parse_consultations(doc)

      paper
    end

    private
    def parse_vorgang(doc)
      vorgang = {}
      doc.css('#smctablevorgang tr').each do |row|
        h = row.css('.smctablehead')
        v = h.xpath('following-sibling::td').text().strip_whitespace
        h = h.text().strip_whitespace.sub(/:$/, "")
        vorgang[h] = v
      end
      vorgang
    end

    def parse_files(doc)
      files = []
      doc.css('table').select do |table|
        table.attr('summary').to_s == "Tabelle enthält zum aufgerufenen Element zugeordnete Dokumente und damit verbundene Aktionen."
      end.each do |table|
        table.css('.smcdocname a').each do |row|
          if row.attr('href').to_s =~ /id=(\d+)/
            files << OParl::File.new(
              { :name => row.attr('title').to_s.strip_whitespace,
                :id => $1
              })
          end
        end
      end
      files
    end

    def parse_consultations(doc)
      consultations = []

      doc.css('table').select do |table|
        table.attr('summary').to_s == "Inhalt der Tabelle: Beratungen der Vorlage" or
        table.attr('summary').to_s == "Inhalt der Tabelle: Weitere Beratungsfolge der Vorlage"
      end.each do |table|
        table.css('tbody tr[valign=top]').each do |row|
          consultation = OParl::Consultation.new
          a = row.css('a[1]')
          unless a.empty?
            link = a.attr('href').to_s
            if link =~ /ksinr=(\d+)/
              consultation.meeting = $1
            end
            if link =~ /kgrnr=(\d+)/
              consultation.organization = [$1]
            end

            consultations << consultation
          end
        end
      end

      consultations
    end
  end

  # Parse the session calendar and yield those session ids containing documents
  class ConferenceCalendarScraper
    include Enumerable

    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

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
      if meeting_url =~ /ksinr=(\d+)/
        meeting.id = $1
      end
      meeting.participant = parse_participants(meeting_url)
      meeting.files = parse_files_table(document_links)
      meeting.files.each do |file|
        case file.name
        when /einladung/i
          meeting.invitation = file.id unless meeting.invitation
        when /niederschrift/i
          meeting.verbatimProtocol = file.id unless meeting.verbatimProtocol
        when /beschlussausfertigung/i, /ergebnisprotokoll/i
          meeting.resultsProtocol = file.id unless meeting.resultsProtocol
        else
          meeting.auxiliaryFile = [] unless meeting.auxiliaryFile
          meeting.auxiliaryFile.push(file.id)
        end
      end
      agenda = parse_agenda_rows(group_content_rows(content_rows))
      meeting.agendaItem = agenda[0]
      meeting.files.concat(agenda[1])
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
          person_id = nil
          if itsUrl =~ /kpenr=(\d+)/
            person_id = $1
          end
          participants.push(
            OParl::Person.new(
            { :id => person_id,
              :name => name.strip_whitespace
            })
          )
        end
      end
      participants
    end

    def parse_agenda_rows(grouped_rows)
      all_files = []
      agenda_items = grouped_rows.map do |rows|
        first_row = rows[0]
        first_row[2].css("br").each{ |br| br.replace "\n" }
        description = first_row[2].text.strip_whitespace

        number = first_row[1].text

        paper = first_row[3].css("smctag_a")
        paper_link = (not paper.empty? and paper.attr('href')).to_s
        if paper_link =~ /kvonr=(\d+)/
          paper_id = $1
        else
          paper_id = nil
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

        agenda_item = OParl::AgendaItem.new(
          { :name => description,
            :consultation => paper_id,
            :number => number,
          })
        files.each do |file|
          case file.name
          when /beschlussausfertigung/i, /ergebnisprotokoll/i
            agenda_item.resolutionFile = file.id unless agenda_item.resolutionFile
          else
            agenda_item.auxiliaryFile = [] unless agenda_item.auxiliaryFile
            agenda_item.auxiliaryFile.push(file.id)
          end
        end
        all_files.concat(files)

        # TODO: deal with decision, vote_result

        agenda_item
      end
      [agenda_items, all_files]
    end

    def parse_files_table(links)
      links.map do |link|
        f = OParl::File.new
        f.fileName = link["href"]
        if f.fileName =~ /0*(\d+)/
          f.id = $1
        end
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
