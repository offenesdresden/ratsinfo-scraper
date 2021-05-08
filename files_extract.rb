#!/usr/bin/env/ruby

require 'open-uri'
require 'json'
require 'fileutils'
require 'socket'
require './dresden_dns_hack'

DIR = "data/files"
Dir.foreach(DIR) do |json_name|
  next unless json_name =~ /\.json$/

  json_path = "#{DIR}/#{json_name}"
  json = JSON.load File.open(json_path)

  if json['mimeType'] == "application/pdf"
    pdf_path = json_path.sub(/\.json$/, ".pdf")
    next if File.exist? pdf_path

    pdf_url = json['downloadUrl']
    puts "GET " + pdf_url
    open pdf_url do |res|
      code = res.status[0]
      raise "HTTP #{code}" if code != "200"

      FileUtils.cp res.path, pdf_path
    end
  else
    puts "Unrecognized MIME type: #{json['mimeType']}"
  end
rescue OpenURI::HTTPError => e
  puts e.message || e
end
