require 'test_helper'
class Bzip2DecompressorTest < MiniTest::Test
  include DecompressorTests

  def setup
    super
    @file = File.new('test/data/file1.txt.bz2', 'rb')
    @decompressor = ::Zip::Bzip2Decompressor.new(@file)
  end

  def teardown
    @file.close
  end
end
