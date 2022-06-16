#!/usr/bin/env/ruby

require 'open-uri'
require 'json'
require 'fileutils'
require 'socket'

DIR = "data/files"
Dir.foreach(DIR) do |json_name|
  next unless json_name =~ /\.json$/

  json_path = "#{DIR}/#{json_name}"
  json = JSON.load File.open(json_path)

  if json['mimeType'] == "application/pdf"
    pdf_path = json_path.sub(/\.json$/, ".pdf")
    txt_path = json_path.sub(/\.json$/, ".txt")
    next if File.exist? txt_path

    unless File.exist? pdf_path
      pdf_url = URI::parse json['downloadUrl'].sub(/^http:/, "https:")
      puts "GET #{pdf_url}"
      tries = 0
      begin
        pdf_url.open do |res|
          code = res.status[0]
          raise "HTTP #{code}" if code != "200"

          IO.copy_stream res, "#{pdf_path}.tmp"
          FileUtils.mv "#{pdf_path}.tmp", pdf_path
        end
      rescue OpenURI::HTTPError => e
        puts e
        next
      rescue
        tries += 1
        if tries < 5
          retry
        else
          raise
        end
      end
    end
    print `pdftotext -enc UTF-8 #{pdf_path} && rm #{pdf_path}`
  else
    puts "Unrecognized MIME type: #{json['mimeType']}"
  end
end
