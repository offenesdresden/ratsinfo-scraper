$:.unshift File.expand_path(File.join(File.dirname(__FILE__), 'lib'))

require 'scrape'
require 'rake/testtask'
require 'json'
require 'pry'
require 'fileutils'
require 'parallel'

CALENDAR_URI = "http://ratsinfo.dresden.de/si0040.php?__cjahr=%d&__cmonat=%s"
SESSION_URI = "http://ratsinfo.dresden.de/si0050.php?__ksinr=%d"
DOWNLOAD_PATH = ENV["DOWNLOAD_PATH"] || File.join(File.dirname(__FILE__), "data")

VORLAGEN_LISTE_URI = "http://ratsinfo.dresden.de/vo0042.php?__cwpall=1"
VORLAGE_URI = "http://ratsinfo.dresden.de/vo0050.php?__kvonr=%s"

ANFRAGEN_LISTE_URI = "http://ratsinfo.dresden.de/ag0041.php?__cwpall=1"
ANFRAGE_URI = "http://ratsinfo.dresden.de/ag0050.php?__kagnr=%s"

GREMIEN_LISTE_URI = "http://ratsinfo.dresden.de/gr0040.php?__cwpall=1&"

PERSON_URI = "http://ratsinfo.dresden.de/kp0050.php?__cwpall=1&__kpenr=%d"

FILE_URI = "http://ratsinfo.dresden.de/getfile.php?id=%s&type=do"

CONCURRENCY = 16

directory DOWNLOAD_PATH

scrape_start_date = Date.new(2009,8)
scrape_end_date = Time.now.to_date

task :default => [:scrape_sessions]

desc "Scrape Documents from http://ratsinfo.dresden.de with a minmal timerange"
task :testmonth do
  scrape_start_date = Date.new(2009, 8)
  scrape_end_date  = Date.new(2009, 8)
  Rake::Task["scrape_sessions"].invoke
end


desc "Scrape Documents from http://ratsinfo.dresden.de"
task :scrape => [
       :scrape_gremien,
       :scrape_people,
       :scrape_anfragen, :scrape_vorlagen,
       :scrape_sessions,
       :fetch_meetings_anfragen,
       :fetch_files
     ]

task :scrape_gremien do
  Scrape::GremienListeScraper.new(GREMIEN_LISTE_URI).each do |organization|
    puts "[#{organization.id}] #{organization.name}"
    organization.save_to File.join(DOWNLOAD_PATH, "gremien", "#{organization.id}.json")
  end
end

task :scrape_people do
  Scrape::PeopleScraper.new(PERSON_URI).each do |person|
    puts "[#{person.id}] #{person.name}"
    person.save_to File.join(DOWNLOAD_PATH, "persons", "#{person.id}.json")
  end
end

task :scrape_sessions do
  raise "download path '#{DOWNLOAD_PATH}' does not exists!" unless Dir.exists?(DOWNLOAD_PATH)
  date_range = (scrape_start_date..scrape_end_date).select {|d| d.day == 1}
  date_range.each do |date|
    uri = sprintf(CALENDAR_URI, date.year, date.month)
    s = Scrape::ConferenceCalendarScraper.new(uri)
    Parallel.each(s, :in_processes => CONCURRENCY) do |session_id|
      session_url = sprintf(SESSION_URI, session_id)
      meeting = Scrape::SessionScraper.new(session_url).scrape
      meeting.id = session_id
      puts "[#{meeting.id}] #{meeting.name}"

      meeting.save_to File.join(DOWNLOAD_PATH, "meetings", "#{meeting.id}.json")
      meeting.persons.each do |person|
        persons_path = File.join(DOWNLOAD_PATH, "persons", "#{person.id}.json")
        person.save_to persons_path
      end
      meeting.files.each do |file|
        file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")
      end
    end
  end
end

task :scrape_vorlagen do
  Parallel.each(Scrape::VorlagenListeScraper.new(VORLAGEN_LISTE_URI), :in_processes => CONCURRENCY) do |paper|
    id = paper.id
    paper = Scrape::PaperScraper.new(sprintf(VORLAGE_URI, id)).scrape
    paper.id = id  # Restore id

    puts "Vorlage #{paper.id} [#{paper.shortName}] #{paper.name}"
    paper.save_to File.join(DOWNLOAD_PATH, "vorlagen", "#{paper.id}.json")
    paper.files.each do |file|
      file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")
    end
  end
end

task :scrape_anfragen do
  Scrape::AnfragenListeScraper.new(ANFRAGEN_LISTE_URI).each do |paper|
    puts "Anfrage #{paper.id} [#{paper.shortName}] #{paper.name}"
    paper.save_to File.join(DOWNLOAD_PATH, "anfragen", "#{paper.id}.json")
    paper.files.each do |file|
      file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")
    end
  end
end


desc "Durchsucht alle Meetings nach weiteren Anfragen"
task :fetch_meetings_anfragen do
  Dir.glob(File.join(DOWNLOAD_PATH, "meetings", "*.json")) do |filename|
    meeting = OParl::Meeting.load_from(filename)
    Parallel.each(meeting.agendaItem, :in_processes => CONCURRENCY) do |agenda_item|
      consultation = agenda_item.consultation
      next unless consultation
      id = consultation.parentID
      paper_path = File.join(DOWNLOAD_PATH, "vorlagen", "#{id}.json")

      paper = Scrape::PaperScraper.new(sprintf(VORLAGE_URI, id)).scrape
      paper.id = id  # Restore id

      puts "Vorlage #{paper.id} [#{paper.shortName}] #{paper.name}"
      paper.save_to paper_path
      paper.files.each do |file|
        file.save_to File.join(DOWNLOAD_PATH, "files", "#{file.id}.json")
      end
    end
  end
end

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
    # We do want to download existing files to monitor for updates,
    # but not at once. Distribute over 1 month:
    if File.exist? pdf_path and id.to_i % 29 != Time.new.day - 1
      next
    end

    puts "Fetch file #{id}: #{file.name}"
    begin
      tmp_file = Scrape.download_file(file.downloadUrl)
      file.fileName = tmp_file.file_name
      file.mimeType = tmp_file.mime_type
      file.size = tmp_file.size
      FileUtils.mv tmp_file.path, pdf_path
      tmp_file.close
      tmp_file = nil
    rescue
      puts "Error downloading #{file.downloadUrl}"
      puts $!
      next
    ensure
      tmp_file.unlink if tmp_file.is_a? File
    end

    if `sha1sum #{pdf_path}` =~ /([0-9a-f]+)/
      file.sha1Checksum = $1
    end
    file.save_to json_path
  end
end

desc "Create plain-text versions of all PDF files, but no other mime-types"
task :pdftotext do
  path = File.join(DOWNLOAD_PATH, "files")
  Dir.foreach path do |filename|
    next unless filename =~ /(.+)\.json$/
    id = $1
    json_path = File.join(path, filename)
    file = OParl::File.load_from(json_path)

    if file.mimeType == 'application/pdf'
      pdf_path = File.join(path, "#{id}.pdf")
      txt_path = File.join(path, "#{id}.txt")

      # Only if .pdf newer than .txt
      if !File.exist?(txt_path) or File.new(pdf_path).mtime > File.new(txt_path).mtime
        puts pdf_path
        output = `pdftotext -enc UTF-8 #{pdf_path}`.chomp
        puts output unless output.empty?
      end
    end
  end
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
end
