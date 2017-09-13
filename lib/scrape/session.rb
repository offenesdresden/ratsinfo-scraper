module Scrape

  def self.get_organization_by_name(name)
    Dir.glob(File.join(DOWNLOAD_PATH, "gremien", "*.json")) do |file_path|
      organization = OParl::Organization.load_from(file_path)
      if organization.name == name
        return organization
      end
    end
    nil
  end

  class SessionScraper
    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def scrape
      doc = Scrape.download_doc(@scrape_url)

      vorgang = Scrape.parse_vorgang(doc.css('#smctablevorgang'))
      meeting = OParl::Meeting.new(
        { :shortName => vorgang['Sitzung'],
          :locality => vorgang['Raum'],
          :name => vorgang['Bezeichnung']
        })
      if (organization = Scrape.get_organization_by_name(vorgang['Gremium']))
        meeting.organization = [organization.id]
      else
        puts "No such organization: #{vorgang['Gremium']}"
      end

      date = vorgang['Datum']
      (start_time, end_time) = vorgang['Zeit'].split("-")
      meeting.start = Time.parse(date + " " + start_time).iso8601
      meeting.end = Time.parse(date + " " + end_time).iso8601 if end_time

      meeting.files = Scrape.parse_docbox(doc.css('.smcdocboxinfo')[0])
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

      agenda = parse_agenda
      meeting.agendaItem = agenda
      agenda.each do |item|
        meeting.files.concat(item.files)
      end
      meeting

      meeting.persons = parse_participants
      meeting.participant = meeting.persons.map { |person| person.id }

      meeting
    end

    private
    def parse_agenda
      agenda_url = @scrape_url.gsub! /\/[a-z0-9]+\.php/, '/to0040.php'
      results = []
      doc = Scrape.download_doc(agenda_url)
      doc.xpath("//table[@id='smc_page_to0040_contenttable1']/tbody/tr[not(@class='smcrowh')]").each do |row|
        item = OParl::AgendaItem.new(
          { :name => row.css('.smc_topht').text().strip_whitespace,
            :number => row.css('.smc_tophn').text().strip_whitespace,
          })

        # Vorlage/Paper.id
        voname = row.css('.smc_field_voname')
        if not voname.empty? and voname.attr('href').to_s =~ /kvonr=(\d+)/
          item.consultation = OParl::Consultation.new(
            { :paper => $1
            })
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
      participant_url = @scrape_url.gsub! /\/[a-z0-9]+\.php/, '/to0045.php'
      participants = Array.new()
      doc = Scrape.download_doc(participant_url)
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
