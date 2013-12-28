require 'minitest/spec'
require 'minitest/autorun'
require 'webmock/minitest'
require 'pry-rescue/minitest'
require 'pry'
require 'vcr'
require 'pathname'

TEST_ROOT = Pathname.new(File.dirname(__FILE__))

def fixture_path(path)
  TEST_ROOT.join("fixtures", path)
end

VCR.configure do |c|
  c.cassette_library_dir = fixture_path('vcr_cassettes')
  c.hook_into :webmock # or :fakeweb
end
