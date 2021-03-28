module Scrape

  class AnfragenListeScraper
    include Enumerable

    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def each(&block)
      doc = Scrape.download_doc(@scrape_url)
      doc.css(".smctableantraege tbody tr").each do |row|
        paper = parse_paper(row)
        yield paper
      end
    end

    private
    def parse_paper(row)
      name = row.css('h4 a')
      if not name.empty? and
        (href = name.attr('href').to_s) and
        href =~ /kagnr=(\d+)/

        OParl::Paper.new(
          { :id => $1,
            :name => name.text().strip_whitespace
          })
      else
        puts "Unexpected Anfrage: #{name.inspect}"
      end
    end
  end
  
end
