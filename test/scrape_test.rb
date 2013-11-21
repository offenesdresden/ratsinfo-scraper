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

describe "scrape session" do
  before do
    VCR.use_cassette('zip_archive') do
      @session_path = Dir.mktmpdir
      session_url = "http://ratsinfo.dresden.de/to0040.php?__ksinr=428"
      @zip_file = Scrape.download_zip_archive(session_url)
      @archive = Scrape::DocumentArchive.new(@zip_file.path)
    end
  end
  it "should download the archive" do
    @zip_file.size.must_be :>, 1E5
    binding.pry
  end
  after do
    FileUtils.remove_entry @session_path
  end
end
