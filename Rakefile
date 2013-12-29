require_relative 'lib/scrape'
require_relative 'lib/pdf_reader'
require 'rake/testtask'

require 'json'
require 'pry'

CALENDAR_URI = "http://ratsinfo.dresden.de/si0040.php?__cjahr=%d&__cmonat=%s"
SESSION_URI = "http://ratsinfo.dresden.de/to0040.php?__ksinr=%d"
DOWNLOAD_PATH = ENV["DOWNLOAD_PATH"] || File.join(File.dirname(__FILE__), "data")

METADATA_FILES = FileList["./data/**/metadata.json"]

directory 'data'

desc "Scrape Documents from http://ratsinfo.dresden.de"
task :scrape => :data do
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
      mkdir_p(session_path)
      session_url = sprintf(SESSION_URI, session_id)
      Scrape.scrape_session(session_url, session_path)
    end
  end
end

desc "Scrape Documents of Session with session_id"
task :scrape_session, :session_id do |t, args|
  session_path = File.join(DOWNLOAD_PATH, args.session_id)
  session_url = sprintf(SESSION_URI, session_id)
  Scrape.scrape_session(session_url, session_path)
end

task :default => [:scrape, :convert]

desc "Convert existing scraped pdfs to plain text files"
task :convert do
  METADATA_FILES.each do |file_name|
    directory = File.dirname(file_name)
    metadata = Metadata.new(JSON.load(File.open(file_name)))
    metadata.each_document do |doc|
      pdf_path = File.join(directory, doc.file_name)
      next unless pdf_path.end_with?(".pdf")

      p = PdfReader.new(pdf_path)
      p.write_pages
      doc.pdf_metadata = p.metadata
    end

    file = File.open(file_name, "w")
    json = JSON.pretty_generate(metadata)
    file.write(json)
  end
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
end
