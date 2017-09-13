# coding: utf-8
module Scrape

  class PaperScraper
    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def scrape
      doc = Scrape.download_doc(@scrape_url)

      vorgang = Scrape.parse_vorgang(doc.css('#smctablevorgang'))
      paper = OParl::Paper.new(
        { :name => vorgang['Betreff'],
          :shortName => vorgang['Name'],
          :reference => vorgang['Name'],
          :paperType => vorgang['Art']
        })
      date_str = vorgang['Datum']
      paper.publishedDate = Date.parse(date_str).iso8601 if date_str

      paper.files = parse_files(doc)
      paper.files.each do |file|
        if file.name == vorgang['Name']
          paper.mainFile = file.id
        else
          paper.auxiliaryFile = [] unless paper.auxiliaryFile
          paper.auxiliaryFile.push(file.id)
        end
      end

      consultations_url = @scrape_url.sub(/vo0050\.php/, "vo0051.php")
      paper.consultation = parse_consultations(consultations_url)

      paper
    end

    private

    def parse_files(doc)
      # TODO: what if there are files but only in agenda items? then
      # they'll end up having .smcdocbox[0], which is not what we want
      # here!
      docbox = doc.css('.smcdocbox')[0]
      docbox ? Scrape.parse_docbox(docbox) : []
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

          a = row.css('td.smc_field_grname a[1]')
          unless a.empty?
            link = a.attr('href').to_s
            if link =~ /ksinr=(\d+)/
              consultation.meeting = $1
            end
          else
            consultation.organization = [
              OParl::Organization.new(:name => row.css('td.smc_field_grname').text)
            ]
          end
          consultation.role = row.css('td.smc_field_txname').text
          if consultation.role =~ /^beschlie/i
            consultation.authoritative = true
          end
          case row.css('td.smc_field_bfost').text.strip
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
