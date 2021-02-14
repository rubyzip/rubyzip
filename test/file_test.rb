require 'test_helper'

class ZipFileTest < MiniTest::Test
  include CommonZipFileFixture
  include ZipEntryData

  OK_DELETE_FILE = 'test/data/generated/okToDelete.txt'
  OK_DELETE_MOVED_FILE = 'test/data/generated/okToDeleteMoved.txt'

  def teardown
    ::Zip.reset!
  end

  def test_create_from_scratch_to_buffer
    comment = 'a short comment'

    buffer = ::Zip::File.add_buffer do |zf|
      zf.get_output_stream('myFile') { |os| os.write 'myFile contains just this' }
      zf.mkdir('dir1')
      zf.comment = comment
    end

    ::File.open(EMPTY_FILENAME, 'wb') { |file| file.write buffer.string }

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    assert_equal(comment, zf_read.comment)
    assert_equal(2, zf_read.entries.length)
  end

  def test_create_from_scratch
    comment = 'a short comment'

    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE)
    zf.get_output_stream('myFile') { |os| os.write 'myFile contains just this' }
    zf.mkdir('dir1')
    zf.comment = comment
    zf.close

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    assert_equal(comment, zf_read.comment)
    assert_equal(2, zf_read.entries.length)
  end

  def test_create_from_scratch_with_old_create_parameter
    comment = 'a short comment'

    zf = ::Zip::File.new(EMPTY_FILENAME, 1)
    zf.get_output_stream('myFile') { |os| os.write 'myFile contains just this' }
    zf.mkdir('dir1')
    zf.comment = comment
    zf.close

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    assert_equal(comment, zf_read.comment)
    assert_equal(2, zf_read.entries.length)
  end

  def test_get_input_stream_stored_with_gpflag_bit3
    ::Zip::File.open('test/data/gpbit3stored.zip') do |zf|
      assert_equal("foo\n", zf.read('foo.txt'))
    end
  end

  def test_get_output_stream
    count = nil
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      count = zf.size
      zf.get_output_stream('new_entry.txt') do |os|
        os.write 'Putting stuff in new_entry.txt'
      end
      assert_equal(count + 1, zf.size)
      assert_equal('Putting stuff in new_entry.txt', zf.read('new_entry.txt'))

      zf.get_output_stream(zf.get_entry('test/data/generated/empty.txt')) do |os|
        os.write 'Putting stuff in data/generated/empty.txt'
      end
      assert_equal(count + 1, zf.size)
      assert_equal('Putting stuff in data/generated/empty.txt', zf.read('test/data/generated/empty.txt'))

      custom_entry_args = [
        TEST_COMMENT, TEST_EXTRA, TEST_COMPRESSED_SIZE, TEST_CRC,
        ::Zip::Entry::STORED, ::Zlib::BEST_SPEED, TEST_SIZE, TEST_TIME
      ]
      zf.get_output_stream('entry_with_custom_args.txt', nil, *custom_entry_args) do |os|
        os.write 'Some data'
      end
      assert_equal(count + 2, zf.size)
      entry = zf.get_entry('entry_with_custom_args.txt')
      assert_equal(custom_entry_args[0], entry.comment)
      assert_equal(custom_entry_args[2], entry.compressed_size)
      assert_equal(custom_entry_args[3], entry.crc)
      assert_equal(custom_entry_args[4], entry.compression_method)
      assert_equal(custom_entry_args[5], entry.compression_level)
      assert_equal(custom_entry_args[6], entry.size)
      assert_equal(custom_entry_args[7], entry.time)

      zf.get_output_stream('entry.bin') do |os|
        os.write(::File.open('test/data/generated/5entry.zip', 'rb').read)
      end
    end

    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_equal(count + 3, zf.size)
      assert_equal('Putting stuff in new_entry.txt', zf.read('new_entry.txt'))
      assert_equal('Putting stuff in data/generated/empty.txt', zf.read('test/data/generated/empty.txt'))
      assert_equal(File.open('test/data/generated/5entry.zip', 'rb').read, zf.read('entry.bin'))
    end
  end

  def test_open_buffer_with_string
    string = File.read('test/data/rubycode.zip')
    ::Zip::File.open_buffer string do |zf|
      assert zf.entries.map(&:name).include?('zippedruby1.rb')
    end
  end

  def test_open_buffer_with_stringio
    string_io = StringIO.new File.read('test/data/rubycode.zip')
    ::Zip::File.open_buffer string_io do |zf|
      assert zf.entries.map(&:name).include?('zippedruby1.rb')
    end
  end

  def test_close_buffer_with_stringio
    string_io = StringIO.new File.read('test/data/rubycode.zip')
    zf = ::Zip::File.open_buffer string_io
    assert_nil zf.close
  end

  def test_open_buffer_no_op_does_not_change_file
    Dir.mktmpdir do |tmp|
      test_zip = File.join(tmp, 'test.zip')
      FileUtils.cp 'test/data/rubycode.zip', test_zip

      # Note: this may change the file if it is opened with r+b instead of rb.
      # The 'extra fields' in this particular zip file get reordered.
      File.open(test_zip, 'rb') do |file|
        Zip::File.open_buffer(file) do
          nil # do nothing
        end
      end

      assert_equal \
        File.binread('test/data/rubycode.zip'),
        File.binread(test_zip)
    end
  end

  def test_open_buffer_close_does_not_change_file
    Dir.mktmpdir do |tmp|
      test_zip = File.join(tmp, 'test.zip')
      FileUtils.cp 'test/data/rubycode.zip', test_zip

      File.open(test_zip, 'rb') do |file|
        zf = Zip::File.open_buffer(file)
        refute zf.commit_required?
        assert_nil zf.close
      end

      assert_equal \
        File.binread('test/data/rubycode.zip'),
        File.binread(test_zip)
    end
  end

  def test_open_buffer_with_io_and_block
    File.open('test/data/rubycode.zip') do |io|
      io.set_encoding(Encoding::BINARY) # not strictly required but can be set
      Zip::File.open_buffer(io) do |zip_io|
        # left empty on purpose
      end
    end
  end

  def test_open_buffer_without_block
    string_io = StringIO.new File.read('test/data/rubycode.zip')
    zf = ::Zip::File.open_buffer string_io
    assert zf.entries.map(&:name).include?('zippedruby1.rb')
  end

  def test_cleans_up_tempfiles_after_close
    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE)
    zf.get_output_stream('myFile') do |os|
      @tempfile_path = os.path
      os.write 'myFile contains just this'
    end

    assert_equal(true, File.exist?(@tempfile_path))

    zf.close

    assert_equal(false, File.exist?(@tempfile_path))
  end

  def test_add_default_compression
    src_file = 'test/data/file2.txt'
    entry_name = 'newEntryName.rb'
    assert(::File.exist?(src_file))
    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE)
    zf.add(entry_name, src_file)
    zf.close

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    entry = zf_read.entries.first
    assert_equal('', zf_read.comment)
    assert_equal(1, zf_read.entries.length)
    assert_equal(entry_name, zf_read.entries.first.name)
    assert_equal(File.size(src_file), entry.size)
    assert_equal(8_764, entry.compressed_size)
    AssertEntry.assert_contents(src_file,
                                zf_read.get_input_stream(entry_name, &:read))
  end

  def test_add_best_compression
    src_file = 'test/data/file2.txt'
    entry_name = 'newEntryName.rb'
    assert(::File.exist?(src_file))
    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE, false, { compression_level: Zlib::BEST_COMPRESSION })
    zf.add(entry_name, src_file)
    zf.close

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    entry = zf_read.entries.first
    assert_equal(1, zf_read.entries.length)
    assert_equal(File.size(src_file), entry.size)
    assert_equal(8_658, entry.compressed_size)
    AssertEntry.assert_contents(src_file,
                                zf_read.get_input_stream(entry_name, &:read))
  end

  def test_add_best_compression_as_default
    ::Zip.default_compression = Zlib::BEST_COMPRESSION

    src_file = 'test/data/file2.txt'
    entry_name = 'newEntryName.rb'
    assert(::File.exist?(src_file))
    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE)
    zf.add(entry_name, src_file)
    zf.close

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    entry = zf_read.entries.first
    assert_equal(1, zf_read.entries.length)
    assert_equal(File.size(src_file), entry.size)
    assert_equal(8_658, entry.compressed_size)
    AssertEntry.assert_contents(src_file,
                                zf_read.get_input_stream(entry_name, &:read))
  end

  def test_add_best_speed
    src_file = 'test/data/file2.txt'
    entry_name = 'newEntryName.rb'
    assert(::File.exist?(src_file))
    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE, false, { compression_level: Zlib::BEST_SPEED })
    zf.add(entry_name, src_file)
    zf.close

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    entry = zf_read.entries.first
    assert_equal(1, zf_read.entries.length)
    assert_equal(File.size(src_file), entry.size)
    assert_equal(10_938, entry.compressed_size)
    AssertEntry.assert_contents(src_file,
                                zf_read.get_input_stream(entry_name, &:read))
  end

  def test_add_best_speed_as_default
    ::Zip.default_compression = Zlib::BEST_SPEED

    src_file = 'test/data/file2.txt'
    entry_name = 'newEntryName.rb'
    assert(::File.exist?(src_file))
    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE)
    zf.add(entry_name, src_file)
    zf.close

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    entry = zf_read.entries.first
    assert_equal(1, zf_read.entries.length)
    assert_equal(File.size(src_file), entry.size)
    assert_equal(10_938, entry.compressed_size)
    AssertEntry.assert_contents(src_file,
                                zf_read.get_input_stream(entry_name, &:read))
  end

  def test_add_stored
    src_file = 'test/data/file2.txt'
    entry_name = 'newEntryName.rb'
    assert(::File.exist?(src_file))
    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE)
    zf.add_stored(entry_name, src_file)
    zf.close

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    entry = zf_read.entries.first
    assert_equal('', zf_read.comment)
    assert_equal(1, zf_read.entries.length)
    assert_equal(entry_name, entry.name)
    assert_equal(File.size(src_file), entry.size)
    assert_equal(entry.size, entry.compressed_size)
    assert_equal(::Zip::Entry::STORED, entry.compression_method)
    AssertEntry.assert_contents(src_file,
                                zf_read.get_input_stream(entry_name, &:read))
  end

  def test_recover_permissions_after_add_files_to_archive
    src_zip = TEST_ZIP.zip_name
    ::File.chmod(0o664, src_zip)
    src_file = 'test/data/file2.txt'
    entry_name = 'newEntryName.rb'
    assert_equal(::File.stat(src_zip).mode, 0o100664)
    assert(::File.exist?(src_zip))
    zf = ::Zip::File.new(src_zip, ::Zip::File::CREATE)
    zf.add(entry_name, src_file)
    zf.close
    assert_equal(::File.stat(src_zip).mode, 0o100664)
  end

  def test_add_existing_entry_name
    assert_raises(::Zip::EntryExistsError) do
      ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
        zf.add(zf.entries.first.name, 'test/data/file2.txt')
      end
    end
  end

  def test_add_existing_entry_name_replace
    called = false
    replaced_entry = nil
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      replaced_entry = zf.entries.first.name
      zf.add(replaced_entry, 'test/data/file2.txt') do
        called = true
        true
      end
    end
    assert(called)
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_contains(zf, replaced_entry, 'test/data/file2.txt')
    end
  end

  def test_add_directory
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      zf.add(TestFiles::EMPTY_TEST_DIR, TestFiles::EMPTY_TEST_DIR)
    end

    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      dir_entry = zf.entries.detect do |e|
        e.name == TestFiles::EMPTY_TEST_DIR + '/'
      end

      assert(dir_entry.directory?)
    end
  end

  def test_remove
    entry, *remaining = TEST_ZIP.entry_names

    FileUtils.cp(TestZipFile::TEST_ZIP2.zip_name, TEST_ZIP.zip_name)

    zf = ::Zip::File.new(TEST_ZIP.zip_name)
    assert(zf.entries.map(&:name).include?(entry))
    zf.remove(entry)
    assert(!zf.entries.map(&:name).include?(entry))
    assert_equal(zf.entries.map(&:name).sort, remaining.sort)
    zf.close

    zf_read = ::Zip::File.new(TEST_ZIP.zip_name)
    assert(!zf_read.entries.map(&:name).include?(entry))
    assert_equal(zf_read.entries.map(&:name).sort, remaining.sort)
    zf_read.close
  end

  def test_rename
    entry, * = TEST_ZIP.entry_names

    zf = ::Zip::File.new(TEST_ZIP.zip_name)
    assert(zf.entries.map(&:name).include?(entry))

    contents = zf.read(entry)
    new_name = 'changed entry name'
    assert(!zf.entries.map(&:name).include?(new_name))

    zf.rename(entry, new_name)
    assert(zf.entries.map(&:name).include?(new_name))

    assert_equal(contents, zf.read(new_name))

    zf.close

    zf_read = ::Zip::File.new(TEST_ZIP.zip_name)
    assert(zf_read.entries.map(&:name).include?(new_name))
    assert_equal(contents, zf_read.read(new_name))
    zf_read.close
  end

  def test_rename_with_each
    zf_name = 'test_rename_zip.zip'
    ::File.unlink(zf_name) if ::File.exist?(zf_name)
    arr = []
    arr_renamed = []
    ::Zip::File.open(zf_name, ::Zip::File::CREATE) do |zf|
      zf.mkdir('test')
      arr << 'test/'
      arr_renamed << 'Ztest/'
      %w[a b c d].each do |f|
        zf.get_output_stream("test/#{f}") { |file| file.puts 'aaaa' }
        arr << "test/#{f}"
        arr_renamed << "Ztest/#{f}"
      end
    end
    zf = ::Zip::File.open(zf_name)
    assert_equal(zf.entries.map(&:name), arr)
    zf.close
    Zip::File.open(zf_name, 'wb') do |z|
      z.each do |f|
        z.rename(f, "Z#{f.name}")
      end
    end
    zf = ::Zip::File.open(zf_name)
    assert_equal(zf.entries.map(&:name), arr_renamed)
    zf.close
    ::File.unlink(zf_name) if ::File.exist?(zf_name)
  end

  def test_rename_to_existing_entry
    old_entries = nil
    ::Zip::File.open(TEST_ZIP.zip_name) { |zf| old_entries = zf.entries }

    assert_raises(::Zip::EntryExistsError) do
      ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
        zf.rename(zf.entries[0], zf.entries[1].name)
      end
    end

    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_equal(old_entries.sort.map(&:name), zf.entries.sort.map(&:name))
    end
  end

  def test_rename_to_existing_entry_overwrite
    old_entries = nil
    ::Zip::File.open(TEST_ZIP.zip_name) { |zf| old_entries = zf.entries }

    called = false
    new_entry_name = nil
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      new_entry_name = zf.entries[0].name
      zf.rename(zf.entries[0], zf.entries[1].name) do
        called = true
        true
      end
    end

    assert(called)
    old_entries.delete_if { |e| e.name == new_entry_name }
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_equal(old_entries.sort.map(&:name),
                   zf.entries.sort.map(&:name))
    end
  end

  def test_rename_non_entry
    non_entry = 'bogusEntry'
    target_entry = 'target_entryName'
    zf = ::Zip::File.new(TEST_ZIP.zip_name)
    assert(!zf.entries.include?(non_entry))
    assert_raises(Errno::ENOENT) { zf.rename(non_entry, target_entry) }
    zf.commit
    assert(!zf.entries.include?(target_entry))
  ensure
    zf.close
  end

  def test_rename_entry_to_existing_entry
    entry1, entry2, * = TEST_ZIP.entry_names
    zf = ::Zip::File.new(TEST_ZIP.zip_name)
    assert_raises(::Zip::EntryExistsError) { zf.rename(entry1, entry2) }
  ensure
    zf.close
  end

  def test_replace
    replace_entry = TEST_ZIP.entry_names[2]
    replace_src = 'test/data/file2.txt'
    zf = ::Zip::File.new(TEST_ZIP.zip_name)
    zf.replace(replace_entry, replace_src)

    zf.close
    zf_read = ::Zip::File.new(TEST_ZIP.zip_name)
    AssertEntry.assert_contents(
      replace_src,
      zf_read.get_input_stream(replace_entry, &:read)
    )
    AssertEntry.assert_contents(
      TEST_ZIP.entry_names[0],
      zf_read.get_input_stream(TEST_ZIP.entry_names[0], &:read)
    )
    AssertEntry.assert_contents(
      TEST_ZIP.entry_names[1],
      zf_read.get_input_stream(TEST_ZIP.entry_names[1], &:read)
    )
    AssertEntry.assert_contents(
      TEST_ZIP.entry_names[3],
      zf_read.get_input_stream(TEST_ZIP.entry_names[3], &:read)
    )
    zf_read.close
  end

  def test_replace_non_entry
    replace_entry = 'nonExistingEntryname'
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_raises(Errno::ENOENT) do
        zf.replace(replace_entry, 'test/data/file2.txt')
      end
    end
  end

  def test_commit
    new_name = 'renamedFirst'
    zf = ::Zip::File.new(TEST_ZIP.zip_name)
    old_name = zf.entries.first
    zf.rename(old_name, new_name)
    zf.commit

    zf_read = ::Zip::File.new(TEST_ZIP.zip_name)
    refute_nil(zf_read.entries.detect { |e| e.name == new_name })
    assert_nil(zf_read.entries.detect { |e| e.name == old_name })
    zf_read.close

    zf.close
    res = system("unzip -tqq #{TEST_ZIP.zip_name}")
    assert_equal(res, true)
  end

  def test_double_commit(filename = 'test/data/generated/double_commit_test.zip')
    ::FileUtils.touch('test/data/generated/test_double_commit1.txt')
    ::FileUtils.touch('test/data/generated/test_double_commit2.txt')
    zf = ::Zip::File.open(filename, ::Zip::File::CREATE)
    zf.add('test1.txt', 'test/data/generated/test_double_commit1.txt')
    zf.commit
    zf.add('test2.txt', 'test/data/generated/test_double_commit2.txt')
    zf.commit
    zf.close
    zf2 = ::Zip::File.open(filename)
    refute_nil(zf2.entries.detect { |e| e.name == 'test1.txt' })
    refute_nil(zf2.entries.detect { |e| e.name == 'test2.txt' })
    res = system("unzip -tqq #{filename}")
    assert_equal(res, true)
  end

  def test_double_commit_zip64
    ::Zip.write_zip64_support = true
    test_double_commit('test/data/generated/double_commit_test64.zip')
  end

  def test_write_buffer
    new_name = 'renamedFirst'
    zf = ::Zip::File.new(TEST_ZIP.zip_name)
    old_name = zf.entries.first
    zf.rename(old_name, new_name)
    io = ::StringIO.new('')
    buffer = zf.write_buffer(io)
    File.open(TEST_ZIP.zip_name, 'wb') { |f| f.write buffer.string }
    zf_read = ::Zip::File.new(TEST_ZIP.zip_name)
    refute_nil(zf_read.entries.detect { |e| e.name == new_name })
    assert_nil(zf_read.entries.detect { |e| e.name == old_name })
    zf_read.close

    zf.close
  end

  # This test tests that after commit, you
  # can delete the file you used to add the entry to the zip file
  # with
  def test_commit_use_zip_entry
    FileUtils.cp(TestFiles::RANDOM_ASCII_FILE1, OK_DELETE_FILE)
    zf = ::Zip::File.open(TEST_ZIP.zip_name)
    zf.add('okToDelete.txt', OK_DELETE_FILE)
    assert_contains(zf, 'okToDelete.txt')
    zf.commit
    File.rename(OK_DELETE_FILE, OK_DELETE_MOVED_FILE)
    assert_contains(zf, 'okToDelete.txt', OK_DELETE_MOVED_FILE)
  end

  #  def test_close
  #    zf = ZipFile.new(TEST_ZIP.zip_name)
  #    zf.close
  #    assert_raises(IOError) {
  #      zf.extract(TEST_ZIP.entry_names.first, "hullubullu")
  #    }
  #  end

  def test_compound1
    renamed_name = 'renamed_name'
    filename_to_remove = ''

    begin
      zf = ::Zip::File.new(TEST_ZIP.zip_name)
      orig_entries = zf.entries.dup

      assert_not_contains(zf, TestFiles::RANDOM_ASCII_FILE1)
      zf.add(TestFiles::RANDOM_ASCII_FILE1,
             TestFiles::RANDOM_ASCII_FILE1)
      assert_contains(zf, TestFiles::RANDOM_ASCII_FILE1)

      entry_to_rename = zf.entries.find do |entry|
        entry.name.match('longAscii')
      end
      zf.rename(entry_to_rename, renamed_name)
      assert_contains(zf, renamed_name)

      TestFiles::BINARY_TEST_FILES.each do |filename|
        zf.add(filename, filename)
        assert_contains(zf, filename)
      end

      assert_contains(zf, orig_entries.last.to_s)
      filename_to_remove = orig_entries.map(&:to_s).find do |name|
        name.match('longBinary')
      end
      zf.remove(filename_to_remove)
      assert_not_contains(zf, filename_to_remove)
    ensure
      zf.close
    end

    begin
      zf_read = ::Zip::File.new(TEST_ZIP.zip_name)
      assert_contains(zf_read, TestFiles::RANDOM_ASCII_FILE1)
      assert_contains(zf_read, renamed_name)
      TestFiles::BINARY_TEST_FILES.each do |filename|
        assert_contains(zf_read, filename)
      end
      assert_not_contains(zf_read, filename_to_remove)
    ensure
      zf_read.close
    end
  end

  def test_compound2
    begin
      zf = ::Zip::File.new(TEST_ZIP.zip_name)
      orig_entries = zf.entries.dup

      orig_entries.each do |entry|
        zf.remove(entry)
        assert_not_contains(zf, entry)
      end
      assert(zf.entries.empty?)

      TestFiles::ASCII_TEST_FILES.each do |filename|
        zf.add(filename, filename)
        assert_contains(zf, filename)
      end
      assert_equal(zf.entries.sort.map(&:name), TestFiles::ASCII_TEST_FILES)

      zf.rename(TestFiles::ASCII_TEST_FILES[0], 'new_name')
      assert_not_contains(zf, TestFiles::ASCII_TEST_FILES[0])
      assert_contains(zf, 'new_name')
    ensure
      zf.close
    end
    begin
      zf_read = ::Zip::File.new(TEST_ZIP.zip_name)
      ascii_files = TestFiles::ASCII_TEST_FILES.dup
      ascii_files.shift
      ascii_files.each do |filename|
        assert_contains(zf, filename)
      end

      assert_contains(zf, 'new_name')
    ensure
      zf_read.close
    end
  end

  def test_change_comment
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      zf.comment = 'my changed comment'
    end
    zf_read = ::Zip::File.open(TEST_ZIP.zip_name)
    assert_equal('my changed comment', zf_read.comment)
  end

  def test_preserve_file_order
    entry_names = nil
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      entry_names = zf.entries.map(&:to_s)
      zf.get_output_stream('a.txt') { |os| os.write 'this is a.txt' }
      zf.get_output_stream('z.txt') { |os| os.write 'this is z.txt' }
      zf.get_output_stream('k.txt') { |os| os.write 'this is k.txt' }
      entry_names << 'a.txt' << 'z.txt' << 'k.txt'
    end

    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_equal(entry_names, zf.entries.map(&:to_s))
      entries = zf.entries.sort_by(&:name).reverse
      entries.each do |e|
        zf.remove e
        zf.get_output_stream(e) { |os| os.write 'foo' }
      end
      entry_names = entries.map(&:to_s)
    end
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_equal(entry_names, zf.entries.map(&:to_s))
    end
  end

  def test_streaming
    fname = ::File.join(::File.expand_path(::File.dirname(__FILE__)), '../README.md')
    zname = 'test/data/generated/README.zip'
    Zip::File.open(zname, Zip::File::CREATE) do |zipfile|
      zipfile.get_output_stream(File.basename(fname)) do |f|
        f.puts File.read(fname)
      end
    end

    data = nil
    File.open(zname, 'rb') do |f|
      Zip::File.open_buffer(f) do |zipfile|
        zipfile.each do |entry|
          next unless entry.name =~ /README.md/

          data = zipfile.read(entry)
        end
      end
    end
    assert data
    assert data =~ /Simonov/
  end

  def test_nonexistant_zip
    assert_raises(::Zip::Error) do
      ::Zip::File.open('fake.zip')
    end
  end

  def test_empty_zip
    assert_raises(::Zip::Error) do
      ::Zip::File.open(TestFiles::NULL_FILE)
    end
  end

  def test_odd_extra_field
    entry_count = 0
    File.open 'test/data/oddExtraField.zip', 'rb' do |zip_io|
      Zip::File.open_buffer zip_io.read do |zip|
        zip.each do |_zip_entry|
          entry_count += 1
        end
      end
    end
    assert_equal 13, entry_count
  end

  def test_open_xls_does_not_raise_type_error
    ::Zip::File.open('test/data/test.xls')
  end

  def test_find_get_entry
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_nil zf.find_entry('not_in_here.txt')

      refute_nil zf.find_entry('test/data/generated/empty.txt')

      assert_raises(Errno::ENOENT) do
        zf.get_entry('not_in_here.txt')
      end

      # Should not raise anything.
      zf.get_entry('test/data/generated/empty.txt')
    end
  end

  private

  def assert_contains(zip_file, entry_name, filename = entry_name)
    refute_nil(
      zip_file.entries.detect { |e| e.name == entry_name },
      "entry #{entry_name} not in #{zip_file.entries.join(', ')} in zip file #{zip_file}"
    )
    assert_entry_contents(zip_file, entry_name, filename) if File.exist?(filename)
  end

  def assert_not_contains(zip_file, entry_name)
    assert_nil(
      zip_file.entries.detect { |e| e.name == entry_name },
      "entry #{entry_name} in #{zip_file.entries.join(', ')} in zip file #{zip_file}"
    )
  end
end
