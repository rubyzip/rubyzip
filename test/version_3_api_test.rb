require 'test_helper'

module Version3APITest
  class ZipEntryTest < MiniTest::Test
    include ZipEntryData
    include ZipV3Assertions

    def test_v3_constructor_and_getters
      refute_v3_api_warning do
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

    def test_basic_constructor
      refute_v3_api_warning do
        ::Zip::Entry.new(TEST_ZIPFILE, TEST_NAME)
      end
    end

    def test_v2_constructor_and_getters
      assert_v3_api_warning do
        entry = ::Zip::Entry.new(TEST_ZIPFILE,
                                 TEST_NAME,
                                 TEST_COMMENT,
                                 TEST_EXTRA,
                                 TEST_COMPRESSED_SIZE,
                                 TEST_CRC,
                                 TEST_COMPRESSIONMETHOD,
                                 TEST_SIZE,
                                 TEST_TIME)

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
  end

  class ZipInputStreamTest < MiniTest::Test
    include ZipV3Assertions

    def test_new_with_old_offset
      assert_v3_api_warning do
        zis = ::Zip::InputStream.new(TestZipFile::TEST_ZIP2.zip_name, 100)
        assert_equal(100, zis.instance_variable_get(:@archive_io).pos)
        zis.close
      end
    end

    def test_new_with_new_offset
      refute_v3_api_warning do
        zis = ::Zip::InputStream.new(TestZipFile::TEST_ZIP2.zip_name, offset: 100)
        assert_equal(100, zis.instance_variable_get(:@archive_io).pos)
        zis.close
      end
    end

    def test_new_with_clashing_offset
      assert_v3_api_warning do
        zis = ::Zip::InputStream.new(TestZipFile::TEST_ZIP2.zip_name, 10, offset: 100)
        assert_equal(100, zis.instance_variable_get(:@archive_io).pos)
        zis.close
      end
    end
  end
end
