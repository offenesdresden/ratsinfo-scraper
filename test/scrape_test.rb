# encoding: UTF-8
require 'test_helper'
require 'scrape'

describe Scrape::ConferenceCalendarScraper do
  it "should return ids" do
    VCR.use_cassette('calendar') do
      url = "http://ratsinfo.dresden.de/si0040.php?__cjahr=2010&__cmonat=1"
      s = Scrape::ConferenceCalendarScraper.new(url)
      a = s.to_a
      expected = ["428", "349", "350", "468", "417", "479", "351", "353", "355", "356", "707", "359",
                  "358", "438", "490", "512", "328", "276", "338", "361", "360", "297", "394", "734",
                  "362", "318", "447", "287", "459", "737", "363"]
      (a - expected).must_be_empty
      a.size.must_equal expected.size
    end
  end
end

describe "scrape session 29" do
  before do
    VCR.use_cassette('zip_archive_29') do
      @session_path = Dir.mktmpdir
      session_url = "http://ratsinfo.dresden.de/to0040.php?__ksinr=29"
      @zip_file = Scrape.download_zip_archive(session_url)
      @archive = Scrape::DocumentArchive.new(@zip_file.path)
    end
  end
  it "should download the archive" do
    @zip_file.size.must_be :>, 1E4
    metadata = @archive.metadata
    parts = metadata.parts
    parts.size.must_equal 12
    first = parts.first
    first.description.must_equal "Nichtannahme der Wahl eines Gewählten und Nachrücken eines Ersatzmitgliedes in den Ortschaftsrat Cossebaude für die SPD"
    first.template_id.must_equal "V-CB0001/09"
    first.vote_result.pro.must_equal 8
    first.vote_result.contra.must_equal 0
    first.vote_result.abstention.must_equal 2
    first.vote_result.prejudiced.must_equal 0

    metadata.documents.size.must_equal 3

    doc = metadata.documents.first
    doc.file_name.must_equal "00003455.pdf"
    doc.description.must_equal "Einladung"
  end
  after do
    FileUtils.remove_entry @session_path
  end
end

describe "scrape session 428" do
  before do
    VCR.use_cassette('zip_archive_428"') do
      @session_path = Dir.mktmpdir
      session_url = "http://ratsinfo.dresden.de/to0040.php?__ksinr=428"
      @zip_file = Scrape.download_zip_archive(session_url)
      @archive = Scrape::DocumentArchive.new(@zip_file.path)
    end
  end
  it "should download the archive" do
    @zip_file.size.must_be :>, 1E4
    metadata = @archive.metadata
    parts = metadata.parts
    parts.size.must_equal 5
    second = parts[1]
    second.description.must_equal "Vorhabenbezogener Bebauungsplan Nr. 693, Dresden-Großzschachwitz, Geschäfts- und Parkhaus Pirnaer Landstraße\nhier:\t1. Aufstellungsbeschluss vorhabenbezogener Bebauungsplan\n\t2. Grenzen des vorhabenbezogenen Bebauungsplans"
    second.template_id.must_equal "V0349/09"
    second.vote_result.pro.must_equal 7
    second.vote_result.contra.must_equal 7
    second.vote_result.abstention.must_equal 1
    second.documents.size.must_equal 4
    second.documents.first.file_name.must_equal "00016276.pdf"
    second.documents.first.description.must_equal "Vorlage Gremien"

    metadata.documents.size.must_equal 2

    doc = metadata.documents.first
    doc.file_name.must_equal "00017280.pdf"
    doc.description.must_equal "Einladung_OBR Leu_2010.01.06"
  end
  after do
    FileUtils.remove_entry @session_path
  end
end
