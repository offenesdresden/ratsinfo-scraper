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

    pdf_url = json['downloadUrl'].sub(/^http:/, "https:")
    puts "GET " + pdf_url
    begin
      open pdf_url do |res|
        code = res.status[0]
        raise "HTTP #{code}" if code != "200"

        IO.copy_stream res, "#{pdf_path}.tmp"
        FileUtils.mv "#{pdf_path}.tmp", pdf_path
      end
    rescue OpenURI::HTTPError => e
      puts e
    end
  else
    puts "Unrecognized MIME type: #{json['mimeType']}"
  end
end
