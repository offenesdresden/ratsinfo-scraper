module Scrape

  class GremienListeScraper
    include Enumerable

    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def each(&block)
      doc = Scrape.download_doc(@scrape_url)
      doc.css('#smc_page_gr0040_contenttable1 td.smc_field_grname a').each do |link|
        if link.attr('href').to_s =~ /kgrnr=(\d+)/
          yield OParl::Organization.new(
                  { :id => $1,
                    :name => link.text()
                  })
        else
          pp link
          raise "Weird gremium link: #{link.attr('href')}"
        end
      end
    end
  end

end
