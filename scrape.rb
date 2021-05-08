#!/usr/bin/env/ruby

require 'open-uri'
require 'json'
require 'socket'
require 'fileutils'

# HACK around missing DNS record
class TCPSocket
  alias :initialize_old :initialize

  def initialize(host=nil, port=0, local_host=nil, local_port=nil)
    # fix broken DNS
    host = "194.49.19.58" if host == "oparl.dresden.de"

    initialize_old(host, port, local_host, local_port)
  end
end

# HTTP/JSON helper
module Scrape
  def self.fetch url
    URI::open url do |res|
      code = res.status[0]
      raise "HTTP #{code}" if code != "200"

      JSON::parse res.read
    end
  end

  def self.fetch_each url
    seen = {}

    while url && !seen.has_key?(url) do
      body = fetch url
      seen[url] = true

      body['data'].each { |item| yield item }

      url = body['links'] && body['links']['next']
    end
  end
end

# Shared base class
class OparlResource
  def self.collect url: nil, data: nil, &block
    Scrape.fetch_each url do |data|
      block.call self.new(data: data)
    end
  end
  
  def initialize url: nil, data: nil
    @data = data || Scrape::fetch(url)
    @url = data['id']

    raise "No URL" unless @url
    raise "No data" unless @data

    type = self.class.to_s.split("::").last
    if data['type'] != "https://schema.oparl.org/1.1/#{type}"
      raise "Invalid OParl schema type: #{data['type'].inspect}"
    end
  end

  def method_missing m
    @data[m.to_s]
  end

  def save_to path
    FileUtils.mkdir_p File::dirname(path)
    File.write path, JSON::pretty_generate(@data)
  end
end

module OParl
  class Body < OparlResource
    def self.collect
      super url: "https://oparl.dresden.de/bodies"
    end

    def organizations &block
      Organization.collect url: @data['organization'], &block
    end

    def people &block
      Person.collect url: @data['person'], &block
    end

    def meetings &block
      Meeting.collect url: @data['meeting'], &block
    end

    def papers &block
      Paper.collect url: @data['paper'], &block
    end

    def memberships &block
      Membership.collect url: @data['membership'], &block
    end

    def locations &block
      Location.collect url: @data['locationList'], &block
    end

    def agendaitems &block
      AgendaItem.collect url: @data['agendaItem'], &block
    end

    def legislativeterms &block
      LegislativeTerm.collect url: @data['legislativeTermList'], &block
    end

    def consultations &block
      Consultation.collect url: @data['consultations'], &block
    end

    def files &block
      File.collect url: @data['files'], &block
    end

    def all_collections &block
      %w(organizations people meetings papers memberships locations agendaitems legislativeterms consultations files).each do |type|
        begin
          send type.intern, &block
        rescue OpenURI::HTTPError => e
          puts "#{type}: #{e.message || e}"
        end
      end
    end
  end

  class Organization < OparlResource; end
  class Person < OparlResource; end
  class Meeting < OparlResource; end
  class Paper < OparlResource; end
  class Membership < OparlResource; end
  class Location < OparlResource; end
  class AgendaItem < OparlResource; end
  class LegislativeTerm < OparlResource; end
  class Consultation < OparlResource; end
  class File < OparlResource; end
end

OParl::Body.collect do |body|
  body.all_collections do |item|

    if item.id =~ /^http:\/\/oparl\.dresden\.de\/bodies\/0001\/(.+)/
      path = $1
      puts "[#{path}] #{item.name || item.role}"
      item.save_to "data/#{path}.json"
    else
      puts "Unexpected id: #{item.id.inspect}"
    end
    STDOUT.flush
  end
end
