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

      vorgang = Scrape.parse_vorgang(doc.css('.smccontenttable'))
      meeting = OParl::Meeting.new(
        { :shortName => vorgang['Sitzung'],
          :locality => vorgang['Raum'],
          :name => doc.css('h1').text
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

      meeting.files = doc.css('.smc-documents').map { |container|
        Scrape.parse_docbox(container)
      }.flatten
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

      # TODO: just no longer shown
      # meeting.persons = parse_participants
      # meeting.participant = meeting.persons.map { |person| person.id }

      meeting
    end

    private
    def parse_agenda
      agenda_url = @scrape_url.gsub! /\/[a-z0-9]+\.asp/, '/si0056.asp'
      results = []
      doc = Scrape.download_doc(agenda_url)
      doc.css(".panel-heading").each do |row|
        name = row.css('.smc-panel-text-title').text.strip_whitespace
        next if name.empty?
        number = row.css('h3 .badge')[0].text.strip_whitespace
        item = OParl::AgendaItem.new(
          { :name => name,
            :number => number,
          })
        row = row.xpath('following-sibling::div')[0]

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

        # Metadata
        if (result_el = row.css('.smc_field_smcdv0_box2_beschluss')[0])
          item.result = result_el.text.sub(/^.+?:\s+/, "")
        end
        if (vote_el = row.css('.smc_field_smcdv0_box2_abstimmung')[0])
          item.vote = parse_vote_text vote_el.text.sub(/^.+?:\s+/, "")
        end

        # Only if valid
        results << item unless item.name.empty?
      end
      results
    end

    # def parse_participants
    #   participant_url = @scrape_url.gsub! /\/[a-z0-9]+\.php/, '/to0045.php'
    #   participants = Array.new()
    #   doc = Scrape.download_doc(participant_url)
    #   doc.css("table.smccontenttable tr").each do |row|
    #     participant = row.css("td a")
    #     if participant.to_s != ''
    #       name = participant.attr('title').to_s()[18..-1]
    #       itsUrl = row.css("td a").attr('href').to_s()
    #       person_id = nil
    #       if itsUrl =~ /kpenr=(\d+)/
    #         person_id = $1
    #       end
    #       participants.push(
    #         OParl::Person.new(
    #         { :id => person_id,
    #           :name => name.strip_whitespace
    #         })
    #       )
    #     end
    #   end
    #   participants
    # end

    VOTE_MAPPING = {
      :yes => 'ja',
      :no => 'nein',
      :neutral => 'enthalt',
      :biased => 'befang',
    }

    def parse_vote_text(text)
      results = {}

      text.scan(/(\w+):\W*(\d+)/).each do |key,value|
        mapping = VOTE_MAPPING.select { |field,key_start|
          key.downcase.start_with? key_start
        }.first
        if mapping
          results[mapping[0]] = value.to_i
        else
          throw "Unrecognized vote: #{{ key => value }.inspect}"
        end
      end

      unless results.empty?
        OParl::VoteResult::new results
      else
        nil
      end
    end

    # Removes whitespace at begin and end of a String
    #
    # Also removes (&nbsp; \xA0) contrary to String#strip
    def strip_text(text)
      text.sub(/^\W+/, "").sub(/\W+$/, "")
    end
  end
end
