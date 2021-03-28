# coding: utf-8
module Scrape

  class PaperScraper
    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def scrape
      doc = Scrape.download_doc(@scrape_url)

      vorgang = Scrape.parse_vorgang(doc.css('.smccontenttable'))
      shortName = vorgang['Vorlage'] || vorgang['Nummer']
      paper = OParl::Paper.new(
        { :name => vorgang['Betreff'],
          :shortName => shortName,
          :reference => shortName,
          :paperType => vorgang['Art']
        })
      date_str = vorgang['Datum']
      paper.publishedDate = Date.parse(date_str).iso8601 if date_str

      paper.files = parse_files(doc)
      paper.files.each do |file|
        if file.name == shortName
          paper.mainFile = file.id
        else
          paper.auxiliaryFile = [] unless paper.auxiliaryFile
          paper.auxiliaryFile.push(file.id)
        end
      end

      consultations_url = @scrape_url.sub(/vo0050\.asp/, "vo0053.asp")
      # TODO: there are no longer any links
      # paper.consultation = parse_consultations(consultations_url)

      paper
    end

    private

    def parse_files(doc)
      # TODO: what if there are files but only in agenda items? then
      # they'll end up having .smcdocbox[0], which is not what we want
      # here!
      doc.css('.smcbox')
        .map { |docbox| Scrape.parse_docbox(docbox) }
        .flatten
    end

    def parse_consultations(url)
      consultations = []

      doc = Scrape.download_doc(url)
      doc.css('table').select do |table|
        table.attr('summary').to_s == "Inhalt der Tabelle: Beratungen der Vorlage" or
        table.attr('summary').to_s == "Inhalt der Tabelle: Weitere Beratungsfolge der Vorlage"
      end.each do |table|
        table.css('> tbody > tr').each do |row|
          consultation = OParl::Consultation.new

          a = row.css('td.grname a[1]')
          unless a.empty?
            link = a.attr('href').to_s
            if link =~ /ksinr=(\d+)/
              consultation.meeting = $1
            end
          else
            consultation.organization = [
              OParl::Organization.new(:name => row.css('td.grname').text)
            ]
          end
          consultation.role = row.css('td.txname').text
          if consultation.role =~ /^beschlie/i
            consultation.authoritative = true
          end
          case row.css('td.bfost').text.strip
          when /nicht.+?ffentlich/i
            consultation.agendaItem = OParl::AgendaItem::new(:public => false)
          when /.+?ffentlich/i
            consultation.agendaItem = OParl::AgendaItem::new(:public => true)
          else
            puts "Cannot determine if consultation is public!"
          end

          consultations << consultation
        end
      end

      consultations
    end
  end

end
