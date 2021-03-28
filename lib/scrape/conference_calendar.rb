module Scrape

  # Parse the session calendar and yield those session ids containing documents
  class ConferenceCalendarScraper
    include Enumerable

    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def each(&block)
      doc = Scrape.download_doc(@scrape_url)
      doc.css(".smctablesitzungen tr").each do |row|
        conference_id = parse_row(row)
        yield conference_id unless conference_id.nil?
      end
    end

    private
    def parse_row(row)
      # doc_cell = row.css(".smcdocbox").first
      # return if doc_cell == nil
      conference_link = row.css(".silink h4 a").first
      if conference_link.nil?
        puts("WARNING conference_link not found")
        return
      end
      conference_link["href"] =~ /ksinr=(\d+)/
      $1
    end
  end

end
