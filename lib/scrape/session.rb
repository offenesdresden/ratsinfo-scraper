module Scrape

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

end
