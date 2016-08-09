module Scrape

  class AnfragenListeScraper
    include Enumerable

    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def each(&block)
      doc = Scrape.download_doc(@scrape_url)
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

end
