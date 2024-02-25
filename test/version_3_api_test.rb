require 'test_helper'

module Version3APITest
  class ZipEntryTest < MiniTest::Test
    include ZipEntryData

    def test_constructor_and_getters
      entry = ::Zip::Entry.new(TEST_ZIPFILE,
                               TEST_NAME,
                               comment: TEST_COMMENT,
                               extra: TEST_EXTRA,
                               compressed_size: TEST_COMPRESSED_SIZE,
                               crc: TEST_CRC,
                               compression_method: TEST_COMPRESSIONMETHOD,
                               size: TEST_SIZE,
                               time: TEST_TIME)

      assert_equal(TEST_COMMENT, entry.comment)
      assert_equal(TEST_COMPRESSED_SIZE, entry.compressed_size)
      assert_equal(TEST_CRC, entry.crc)
      assert_instance_of(::Zip::ExtraField, entry.extra)
      assert_equal(TEST_COMPRESSIONMETHOD, entry.compression_method)
      assert_equal(TEST_NAME, entry.name)
      assert_equal(TEST_SIZE, entry.size)
      assert_equal(TEST_TIME, entry.time)
    end
  end

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
