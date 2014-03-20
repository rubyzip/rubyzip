require 'test_helper'
class InflaterTest < MiniTest::Unit::TestCase
  include DecompressorTests

  def setup
    super
    @file = File.new("test/data/file1.txt.deflatedData", "rb")
    @decompressor = ::RubyZip::Inflater.new(@file)
  end

  def teardown
    @file.close
  end
end
