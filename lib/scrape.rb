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

class String
  # remove in addition to builtin strip also Non-Breaking Space
  def strip_whitespace
    gsub(/\A[[:space:]]+|[[:space:]]+\z/, '')
  end
end

module Scrape
  def self.download_file(uri)
    archive = Tempfile.new("ratsinfo")
    agent = Mechanize.new
    agent.pluggable_parser.default = Mechanize::Download
    agent.get(uri).save!(archive.path)
    archive
  end

  def self.parse_vorgang(container)
    vorgang = {}
    container.css('.smctablehead').each do |h|
      k = h.text().strip_whitespace.sub(/:$/, "")
      v = h.xpath('following-sibling::td[1]').text().strip_whitespace
      vorgang[k] = v
    end
    vorgang
  end

  # TODO: unify into using this one
  def self.parse_docbox(container)
    files = []
    container.css('.smcdocname a').each do |row|
      if row.attr('href').to_s =~ /id=(\d+)/
        f = OParl::File.new(
          { :name => row.attr('title').to_s.strip_whitespace,
            :id => $1
          })
        files << f
      end
    end
    files
  end

  # TODO: resolve organization, perhaps in another Rake step?
  class SessionScraper
    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def scrape
      doc = Nokogiri::HTML(open(@scrape_url))

      vorgang = Scrape.parse_vorgang(doc.css('#smctablevorgang'))
      meeting = OParl::Meeting.new(
        { :shortName => vorgang['Sitzung'],
          :organization => [vorgang['Gremium']],
          :locality => vorgang['Raum'],
          :name => vorgang['Bezeichnung'],
          :downloaded_at => Time.new.iso8601
        })
      date = vorgang['Datum']
      (start_time, end_time) = vorgang['Zeit'].split("-")
      meeting.start = Time.parse(date + " " + start_time).iso8601
      meeting.end = Time.parse(date + " " + end_time).iso8601 if end_time

      meeting.files = Scrape.parse_docbox(doc.css('.smcdocbox[1]'))
      meeting.files.each do |file|
        if file.name =~ /einladung/i and not meeting.invitation
          meeting.invitation = file.id
        elsif file.name =~ /niederschrift/i and not meeting.verbatimProtocol
          meeting.verbatimProtocol = file.id
        elsif (file.name =~ /beschlussausfertigung/i or file.name =~ /ergebnisprotokoll/i) and not meeting.resultsProtocol
          meeting.resultsProtocol = file.id
        else
          meeting.auxiliaryFile = [] unless meeting.auxiliaryFile
          meeting.auxiliaryFile.push(file.id)
        end
      end

      agenda = parse_agenda(doc)
      meeting.agendaItem = agenda
      agenda.each do |item|
        meeting.files.concat(item.files)
      end
      meeting.downloaded_at = Time.now
      meeting

      meeting.persons = parse_participants
      meeting.participant = meeting.persons.map { |person| person.id }

      meeting
    end

    private
    def parse_agenda(doc)
      results = []
      doc.xpath("//table[@id='smc_page_to0040_contenttable1']/tbody/tr[not(@class='smcrowh')]").each do |row|
        item = OParl::AgendaItem.new(
          { :name => row.css('.smc_topht').text().strip_whitespace,
            :number => row.css('.smc_tophn').text().strip_whitespace,
          })

        # Vorlage/Paper.id
        voname = row.css('.smc_field_voname')
        if not voname.empty? and voname.attr('href').to_s =~ /kvonr=(\d+)/
          item.consultation = $1
        end

        # AgendaItem files
        item.files = Scrape.parse_docbox(row)
        item.files.each do |file|
          if (file.name =~ /beschlussausfertigung/i or file.name =~ /ergebnisprotokoll/i) and not item.resolutionFile
            item.resolutionFile = file.id
          else
            item.auxiliaryFile = [] unless item.auxiliaryFile
            item.auxiliaryFile.push(file.id)
          end
        end

        # Only if valid
        results << item unless item.name.empty?
      end
      results
    end

    def parse_participants
      participant_url = @scrape_url.gsub! '/to0040.php', '/to0045.php'
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
      paper.files = Scrape.parse_docbox(row)
      paper.files.each do |f|
        if not paper.mainFile and f.name == paper.shortName
          paper.mainFile = f.id
        else
          paper.auxiliaryFile = [] unless paper.auxiliaryFile
          paper.auxiliaryFile << f.id
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

      vorgang = Scrape.parse_vorgang(doc.css('#smctablevorgang'))
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

end
