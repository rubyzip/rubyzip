# frozen_string_literal: true

require 'minitest/autorun'
require 'zip'
require 'gentestfiles'

require_relative 'helpers/assert_entry'
require_relative 'helpers/crc_tests'
require_relative 'helpers/common_zipfile_fixtures'
require_relative 'helpers/decompressor_tests'
require_relative 'helpers/extra_assertions'
require_relative 'helpers/zip_entry_data'

TestFiles.create_test_files
TestZipFile.create_test_zips

Minitest.after_run do
  FileUtils.rm_rf('test/data/generated')
end

Minitest::Test.make_my_diffs_pretty!
