# coding: utf-8

require 'uri'


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
          person.id = @i.to_s
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
        scrape_info(@scrape_url.sub(/kp0050/, "kp0051"), person)
        person
      else
        nil
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

    def scrape_info(scrape_url, person)
      doc = Nokogiri::HTML(open(scrape_url))

      # Scrape keys/values
      doc.css('#smctablevorgang tbody tr').each do |row|
        k = row.css('.smctablehead').text().to_s.sub(/:$/, "")
        v = row.css('.smctablecontent').text().to_s

        case k
        when "E-Mail"
          person.email = [] unless person.email
          v.split(/[,;\/]/).each do |vs|
            vs = vs.strip_whitespace
            unless vs.empty?
              person.email.push(vs)
            end
          end
        when "Mitgliedschaft"
          person.status = v
        when "Straße"
          person.streetAddress = v
        when "Ort"
          if v =~ /^(\d{5}) ([\S\-]+) \(?OT ([\S\-]+)\)?$/
            # "01465 Dresden OT Schönborn"
            # "01156 Dresden (OT Gompitz)"
            person.postalCode = $1
            person.locality = $2
            person.subLocality = $3
          elsif v =~ /^(\d{5}) ([\S\-]+)$/
            # "01069 Dresden"
            person.postalCode = $1
            person.locality = $2
          elsif v =~ /^([\S\-]+)$/
            # "Dresden"
            person.locality = v
          else
            puts "Unerwarteter Ort: #{v}"
          end
        when /^Telefon/, /^Mobil/
          person.phone = [] unless person.phone
          person.phone.push(v)
        when "Beruf"
          person.life = v
        else
          puts "Unerwartete Info: #{k}=#{v}"
        end
      end

      # Scrape picture
      doc.css('img.smcimgperson').each do |img|
        person.photo = URI.join(scrape_url, img.attr('src').to_s).to_s
      end

      person
    end
  end

end
