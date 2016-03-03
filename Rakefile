$:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'scrape'
require 'rake/testtask'
require 'json'
require 'pry'
require 'fileutils'

CALENDAR_URI = "http://ratsinfo.dresden.de/si0040.php?__cjahr=%d&__cmonat=%s"
SESSION_URI = "http://ratsinfo.dresden.de/to0040.php?__ksinr=%d"
DOWNLOAD_PATH = ENV["DOWNLOAD_PATH"] || File.join(File.dirname(__FILE__), "data")

VORLAGEN_LISTE_PATH = "http://ratsinfo.dresden.de/vo0042.php?__cwpall=1"
VORLAGE_PATH = "http://ratsinfo.dresden.de/vo0050.php?__kvonr=%s"

ANFRAGEN_LISTE_PATH = "http://ratsinfo.dresden.de/ag0041.php?__cwpall=1"
ANFRAGE_PATH = "http://ratsinfo.dresden.de/ag0050.php?__kagnr=%s"

FILE_URI = "http://ratsinfo.dresden.de/getfile.php?id=%s&type=do"

METADATA_FILES = FileList["./data/**/metadata.json"]

directory DOWNLOAD_PATH

desc "Scrape Documents from http://ratsinfo.dresden.de"
task :scrape => [:scrape_anfragen, :scrape_vorlagen, :scrape_sessions, :fetch_files]

task :scrape_sessions do
  raise "download path '#{DOWNLOAD_PATH}' does not exists!" unless Dir.exists?(DOWNLOAD_PATH)
  date_range = (Date.new(2012, 01)..Time.now.to_date).select {|d| d.day == 1}
  date_range.each do |date|
    uri = sprintf(CALENDAR_URI, date.year, date.month)
    s = Scrape::ConferenceCalendarScraper.new(uri)
    s.each do |session_id|
      session_path = File.join(DOWNLOAD_PATH, "meetings", session_id)
      if Dir.exists?(session_path)
        puts("#skip #{session_id}")
        next
      end
      puts "from date: #{date}"
      mkdir_p(session_path)
      session_url = sprintf(SESSION_URI, session_id)

      meeting = Scrape.scrape_session(session_url, session_path)

      meeting.save_to File.join(session_path, "#{meeting.id}.json")
      meeting.persons.each do |person|
        person.save_to File.join(DOWNLOAD_PATH, "persons", "#{person.id}.json")
      end
      meeting.files.each do |file|
        file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")

        # Move PDF file
        pdf_old = File.join(session_path, file.fileName)
        pdf_new = File.join(DOWNLOAD_PATH, "files", "#{file.id}.pdf")
        FileUtils.mv pdf_old, pdf_new
      end
    end
  end
end

task :scrape_vorlagen do
  Scrape::VorlagenListeScraper.new(VORLAGEN_LISTE_PATH).each do |paper|
    id = paper.id
    paper = Scrape::PaperScraper.new(sprintf(VORLAGE_PATH, id)).scrape
    paper.id = id  # Restore id

    puts "Vorlage #{paper.id} [#{paper.shortName}] #{paper.name}"
    paper.save_to File.join(DOWNLOAD_PATH, "vorlagen", "#{paper.id}.json")
    paper.files.each do |file|
      file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")
    end
  end
end

task :scrape_anfragen do
  Scrape::AnfragenListeScraper.new(ANFRAGEN_LISTE_PATH).each do |paper|
    puts "Anfrage #{paper.id} [#{paper.shortName}] #{paper.name}"
    paper.save_to File.join(DOWNLOAD_PATH, "anfragen", "#{paper.id}.json")
    paper.files.each do |file|
      file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")
    end
  end
end

desc "Scrape Documents of Session with session_id"
task :scrape_session, :session_id do |t, args|
  session_path = File.join(DOWNLOAD_PATH, args.session_id)
  mkdir_p(session_path)
  session_url = sprintf(SESSION_URI, args.session_id)
  Scrape.scrape_session(session_url, session_path)
end

task :default => [:scrape]

desc "Ensure all known PDF files are fetched, even those not included in Meetings but referenced by Papers"
task :fetch_files do
  path = File.join(DOWNLOAD_PATH, "files")
  Dir.foreach path do |filename|
    next unless filename =~ /(.+)\.json$/
    id = $1

    json_path = File.join(path, filename)
    file = OParl::File.load_from(json_path)
    file.downloadUrl = sprintf(FILE_URI, id)

    pdf_path = File.join(path, "#{id}.pdf")
    unless File.exist? pdf_path
      puts "Fetch file #{id}: #{file.name}"
      begin
        tmp_file = Scrape.download_file(file.downloadUrl)
        FileUtils.mv tmp_file.path, pdf_path

        tmp_file.close
        tmp_file = nil
      ensure
        tmp_file.unlink if tmp_file.is_a? File
      end
    end

    file.mimeType = "application/pdf"
    file.size = File.size(pdf_path)
    if `sha1sum #{pdf_path}` =~ /([0-9a-f]+)/
      file.sha1Checksum = $1
    end
    file.save_to json_path
  end
end

desc "Convert existing scraped pdfs to plain text files"
task :convert do
  METADATA_FILES.each do |file_name|
    directory = File.dirname(file_name)
    metadata = Metadata.new(JSON.load(File.open(file_name)))
    metadata.each_document do |doc|
      pdf_path = File.join(directory, doc.file_name)
      next unless pdf_path.end_with?(".pdf")

      tika = TikaApp.new(pdf_path)
      xmlfile_path = pdf_path.sub('.pdf','.xml')
      xmlfile = open(xmlfile_path, "w+")
      xmlfile.write(tika.get_xml)

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
