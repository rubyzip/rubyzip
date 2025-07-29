# frozen_string_literal: true

module ZipEntryData
  TEST_ZIPFILE = 'someZipFile.zip'
  TEST_COMMENT = 'a comment'
  TEST_COMPRESSED_SIZE = 1234
  TEST_CRC = 325_324
  TEST_EXTRA = 'Some data here'
  TEST_COMPRESSIONMETHOD = ::Zip::Entry::DEFLATED
  TEST_COMPRESSIONLEVEL = ::Zip.default_compression
  TEST_NAME = 'entry name'
  TEST_SIZE = 8432
  TEST_ISDIRECTORY = false
  TEST_TIME = Time.now
end
