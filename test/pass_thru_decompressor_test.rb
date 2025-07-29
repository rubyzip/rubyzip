# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'helpers/decompressor_tests'

class PassThruDecompressorTest < Minitest::Test
  include DecompressorTests

  def setup
    super
    @file = File.new(TEST_FILE, 'rb')
    @decompressor = ::Zip::PassThruDecompressor.new(@file, File.size(TEST_FILE))
  end

  def teardown
    @file.close
  end
end
