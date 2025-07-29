# frozen_string_literal: true

require 'test_helper'
class InflaterTest < Minitest::Test
  include DecompressorTests

  def setup
    super
    @file = File.new('test/data/file1.txt.deflatedData', 'rb')
    @decompressor = ::Zip::Inflater.new(@file)
  end

  def teardown
    @file.close
  end
end
