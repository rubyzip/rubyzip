# frozen_string_literal: true

require_relative 'assert_entry'

module CommonZipFileFixture
  include AssertEntry

  EMPTY_FILENAME = 'emptyZipFile.zip'

  TEST_ZIP = TestZipFile::TEST_ZIP2.clone
  TEST_ZIP.zip_name = 'test/data/generated/5entry_copy.zip'

  def setup
    FileUtils.rm_f(EMPTY_FILENAME)
    FileUtils.cp(TestZipFile::TEST_ZIP2.zip_name, TEST_ZIP.zip_name)
  end
end
