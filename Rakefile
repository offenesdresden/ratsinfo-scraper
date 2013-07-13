require './lib/scrape'
require 'tempfile'
require 'json'

CALENDAR_URI = "http://ratsinfo.dresden.de/si0040.php?__cjahr=%d&__cmonat=%s"
SESSION_URI = "http://ratsinfo.dresden.de/to0040.php?__ksinr=%d"
DOWNLOAD_PATH = ENV["DOWNLOAD_PATH"] || File.join(File.dirname(__FILE__), "data")

desc "Scrape Documents from http://ratsinfo.dresden.de"
task :scrape do
  raise "download path '#{DOWNLOAD_PATH}' does not exists!" unless Dir.exists?(DOWNLOAD_PATH)

  date_range = (Date.new(2008, 01)..Time.now.to_date).select {|d| d.day == 1}
  date_range.each do |date|
    uri = sprintf(CALENDAR_URI, date.year, date.month)
    s = Scrape::ConferenceCalendarScraper.new(uri)
    s.each do |session_id|
      session_path = File.join(DOWNLOAD_PATH, session_id)
      if Dir.exists?(session_path)
        puts("#skip #{session_id}")
        next
      end
      mkdir(session_path)

      begin
        session_url = sprintf(SESSION_URI, session_id)
        tmp_file = Scrape.download_zip_archive(session_url)

        archive = Scrape::DocumentArchive.new(tmp_file.path)
        archive.extract(session_path)

        metadata_path = File.join(session_path, "metadata.json")
        metadata_file = open(metadata_path, "w+")
        metadata = archive.metadata
        metadata[:session_url] = session_url
        json = JSON.pretty_generate(metadata)
        metadata_file.write(json)
        tmp_file.unlink
      rescue Exception => e
        puts e.message
        puts e.backtrace
        rm_r session_path
      end
    end
  end
end
