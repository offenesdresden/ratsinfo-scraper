require 'json'
require 'nokogiri'
require 'open-uri'
require 'cgi'
require 'mechanize'
require 'pry'
require 'zip'
require 'date'
require 'tempfile'
require 'stringio'
require_relative 'metadata.rb'

class String
  # remove in addition to builtin strip also Non-Breaking Space
  def strip_whitespace
    gsub(/\A[[:space:]]+|[[:space:]]+\z/, '')
  end
end

require_relative "scrape/gremien_liste"
require_relative "scrape/person"
require_relative "scrape/conference_calendar"
require_relative "scrape/session"
require_relative "scrape/anfragen_liste"
require_relative "scrape/vorlagen_liste"
require_relative "scrape/paper"


class Download
  def initialize(uri)
    agent = Mechanize.new
    agent.pluggable_parser.default = Mechanize::Download
    @page = agent.get(uri)
    @archive = Tempfile.new("ratsinfo")
    @page.save!(path)
  end

  def close
    @archive.close
  end

  def path
    @archive.path
  end

  def file_name
    if @page['content-disposition'] =~ /filename="(.+?)"/
      $1
    end
  end

  def mime_type
    @page['content-type']
  end

  def size
    @page['content-length'].to_i or File.size(path)
  end
end

module Scrape
  def self.download_file(uri)
    Download::new(uri)
  end

  def self.parse_vorgang(container)
    vorgang = {}
    container.css('.smctablehead').each do |h|
      k = h.text().strip_whitespace.sub(/:$/, "")
      v = h.xpath('following-sibling::td[1]').text().strip_whitespace
      vorgang[k] = v
    end
    vorgang
  end

  def self.parse_docbox(container)
    files = []
    container.css('.smcdocname a').each do |row|
      if row.attr('href').to_s =~ /id=(\d+)/
        f = OParl::File.new(
          { :name => row.attr('title').to_s.strip_whitespace,
            :id => $1
          })
        files << f
      end
    end
    files
  end

end
