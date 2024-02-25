require 'test_helper'

module Version3APITest
  class ZipInputStreamTest < MiniTest::Test
    def test_new_with_old_offset
      zis = ::Zip::InputStream.new(TestZipFile::TEST_ZIP2.zip_name, 100)
      assert_equal(100, zis.instance_variable_get(:@archive_io).pos)
      zis.close
    end

    def test_new_with_new_offset
      zis = ::Zip::InputStream.new(TestZipFile::TEST_ZIP2.zip_name, offset: 100)
      assert_equal(100, zis.instance_variable_get(:@archive_io).pos)
      zis.close
    end

    def test_new_with_clashing_offset
      zis = ::Zip::InputStream.new(TestZipFile::TEST_ZIP2.zip_name, 10, offset: 100)
      assert_equal(100, zis.instance_variable_get(:@archive_io).pos)
      zis.close
    end
  end
end
