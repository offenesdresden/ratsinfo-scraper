module Scrape

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

end
