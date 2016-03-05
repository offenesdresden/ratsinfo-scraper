module Scrape

  # Try all person ids until no valid occurs for MAX_GAP consecutive scrapes
  class PeopleScraper
    include Enumerable

    MAX_GAP = 100
    
    def initialize(uri_template)
      @uri_template = uri_template
      @i = 0
      @gap = 0
    end

    def each(&block)
      while @gap < MAX_GAP
        @i += 1
        person = PersonScraper.new(sprintf(@uri_template, @i)).scrape
        if person
          person.id = @i
          yield person
          @gap = 0
        else
          puts "No person ##{@i}, #{MAX_GAP - @gap} to go"
          @gap += 1
        end
      end
    end
  end

  class PersonScraper
    def initialize(scrape_url)
      @scrape_url = scrape_url
    end

    def scrape
      doc = Nokogiri::HTML(open(@scrape_url))
      name = doc.css('h1.smc_h1').text()
      if name and not name.empty?
        person = OParl::Person.new(
          { :name => name
          })
        person.membership = parse_memberships(doc.css('#smc_page_kp0050_contenttable1 tbody tr'))
        person
      end
    end

    private
    def parse_memberships(rows)
      rows.map do |row|
        m = OParl::Membership.new(
          {
            :role => row.css('.smc_field_amname').text(),
          })
        name = row.css('.smc_field_grname a')
        if not name.empty? and name.attr('href').to_s =~ /kgrnr=(\d+)/
          m.organization = $1
        end
        if (start_date = row.css('.smc_field_mgadat').text().strip_whitespace) and not start_date.empty?
          m.startDate = Date.parse(start_date).iso8601
        end
        if (end_date = row.css('.smc_field_mgedat').text().strip_whitespace) and not end_date.empty?
          m.endDate = Date.parse(end_date).iso8601
        end
        m
      end
    end
  end

end
