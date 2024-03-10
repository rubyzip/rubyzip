require 'test_helper'

module Version3APITest
  class ZipFileTest < MiniTest::Test
    include CommonZipFileFixture
    include ZipV3Assertions

    def test_new
      assert_v3_api_warning do
        file = ::Zip::File.new(TEST_ZIP.zip_name, true, false, restore_times: true) {}
        assert(file.restore_times)
        refute(file.restore_permissions)
      end

      assert_v3_api_warning do
        string_io = StringIO.new(File.read('test/data/rubycode.zip'))
        file = ::Zip::File.new(string_io, false, true, restore_times: true) {}
        assert(file.restore_times)
        refute(file.restore_permissions)
      end

      refute_v3_api_warning do
        file = ::Zip::File.new(TEST_ZIP.zip_name, create: true, restore_times: true) {}
        assert(file.restore_times)
        refute(file.restore_permissions)
      end

      refute_v3_api_warning do
        string_io = StringIO.new(File.read('test/data/rubycode.zip'))
        file = ::Zip::File.new(string_io, buffer: true, restore_times: true) {}
        assert(file.restore_times)
        refute(file.restore_permissions)
      end
    end

    def test_open
      refute_v3_api_warning do
        file = ::Zip::File.open('test/data/rubycode.zip', restore_permissions: true)
        assert(file.restore_permissions)
        refute(file.restore_times)
        file.close
      end

      assert_v3_api_warning do
        file = ::Zip::File.open(TEST_ZIP.zip_name, true, restore_permissions: true)
        assert(file.restore_permissions)
        refute(file.restore_times)
        file.close
      end

      refute_v3_api_warning do
        file = ::Zip::File.open(TEST_ZIP.zip_name, create: true, restore_permissions: true)
        assert(file.restore_permissions)
        refute(file.restore_times)
        file.close
      end
    end

    def test_add_buffer
      assert_v3_api_warning do
        Zip::File.add_buffer {}
      end
    end

    def test_get_output_stream
      refute_v3_api_warning do
        zf = ::Zip::File.new(EMPTY_FILENAME, create: true)
        zf.get_output_stream('myFile') { |os| os.write 'myFile contains just this' }
        zf.close
      end

      assert_v3_api_warning do
        zf = ::Zip::File.new(EMPTY_FILENAME, create: true)
        zf.get_output_stream('myFile', 0o644) { |os| os.write 'myFile contains just this' }
        zf.close
      end
    end
  end

  class ZipEntryTest < MiniTest::Test
    include ZipEntryData
    include ZipV3Assertions

    def test_v3_constructor_and_getters
      refute_v3_api_warning do
        entry = ::Zip::Entry.new(TEST_ZIPFILE,
                                 TEST_NAME,
                                 comment:            TEST_COMMENT,
                                 extra:              TEST_EXTRA,
                                 compressed_size:    TEST_COMPRESSED_SIZE,
                                 crc:                TEST_CRC,
                                 compression_method: TEST_COMPRESSIONMETHOD,
                                 size:               TEST_SIZE,
                                 time:               TEST_TIME)

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

    def test_open
      refute_v3_api_warning do
        ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) {}
      end

      refute_v3_api_warning do
        ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name, decrypter: true) {}
      end

      assert_v3_api_warning do
        ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name, 100, nil) {}
      end
    end

    def test_open_buffer
      assert_v3_api_warning do
        ::Zip::InputStream.open_buffer(StringIO.new(''))
      end
    end
  end

  class ZipOutputStreamTest < MiniTest::Test
    include ZipV3Assertions

    TEST_ZIP = TestZipFile::TEST_ZIP2.clone
    TEST_ZIP.zip_name = 'test/data/generated/output.zip'

    def test_new
      refute_v3_api_warning do
        ::Zip::OutputStream.new(TEST_ZIP.zip_name)
      end

      refute_v3_api_warning do
        ::Zip::OutputStream.new(StringIO.new(''), stream: true)
      end

      assert_v3_api_warning do
        ::Zip::OutputStream.new(StringIO.new(''), true)
      end

      refute_v3_api_warning do
        ::Zip::OutputStream.new(TEST_ZIP.zip_name, stream: false, encrypter: true)
      end

      assert_v3_api_warning do
        ::Zip::OutputStream.new(TEST_ZIP.zip_name, false, true)
      end
    end

    def test_open
      refute_v3_api_warning do
        ::Zip::OutputStream.open(TEST_ZIP.zip_name) {}
      end

      refute_v3_api_warning do
        ::Zip::OutputStream.open(TEST_ZIP.zip_name, encrypter: true) {}
      end

      assert_v3_api_warning do
        ::Zip::OutputStream.open(TEST_ZIP.zip_name, true) {}
      end
    end

    def test_write_buffer
      refute_v3_api_warning do
        ::Zip::OutputStream.write_buffer(StringIO.new('')) {}
      end

      refute_v3_api_warning do
        ::Zip::OutputStream.write_buffer(StringIO.new(''), encrypter: true) {}
      end

      assert_v3_api_warning do
        ::Zip::OutputStream.write_buffer(StringIO.new(''), true) {}
      end
    end
  end

  class ZipFileSplitTest < MiniTest::Test
    include ZipV3Assertions

    TEST_ZIP = TestZipFile::TEST_ZIP2.clone
    TEST_ZIP.zip_name = 'large_zip_file.zip'

    def setup
      FileUtils.cp(TestZipFile::TEST_ZIP2.zip_name, TEST_ZIP.zip_name)
    end

    def teardown
      File.delete(TEST_ZIP.zip_name)

      Dir["#{TEST_ZIP.zip_name}.*"].each do |zip_file_name|
        File.delete(zip_file_name) if File.exist?(zip_file_name)
      end
    end

    def test_old_split
      assert_v3_api_warning do
        Zip::File.split(TEST_ZIP.zip_name, 65_536, false)
      end
    end

    def test_new_split
      refute_v3_api_warning do
        Zip::File.split(TEST_ZIP.zip_name, segment_size: 65_536, delete_zip_file: false)
      end
    end
  end

  class ZipDOSTimeTest < MiniTest::Test
    include ZipV3Assertions

    def test_dos_equals
      assert_v3_api_warning do
        time = ::Zip::DOSTime.now
        assert(time.dos_equals(time))
      end
    end
  end
end
