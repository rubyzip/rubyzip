require 'test_helper'

class ZipEntryTest < MiniTest::Unit::TestCase
  TEST_ZIPFILE = "someZipFile.zip"
  TEST_COMMENT = "a comment"
  TEST_COMPRESSED_SIZE = 1234
  TEST_CRC = 325324
  TEST_EXTRA = "Some data here"
  TEST_COMPRESSIONMETHOD = ::RubyZip::Entry::DEFLATED
  TEST_NAME = "entry name"
  TEST_SIZE = 8432
  TEST_ISDIRECTORY = false
  TEST_TIME = Time.now

  def test_constructorAndGetters
    entry = ::RubyZip::Entry.new(TEST_ZIPFILE,
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
    assert_instance_of(::RubyZip::ExtraField, entry.extra)
    assert_equal(TEST_COMPRESSIONMETHOD, entry.compression_method)
    assert_equal(TEST_NAME, entry.name)
    assert_equal(TEST_SIZE, entry.size)
    assert_equal(TEST_TIME, entry.time)
  end

  def test_is_directoryAndIsFile
    assert(::RubyZip::Entry.new(TEST_ZIPFILE, "hello").file?)
    assert(!::RubyZip::Entry.new(TEST_ZIPFILE, "hello").directory?)

    assert(::RubyZip::Entry.new(TEST_ZIPFILE, "dir/hello").file?)
    assert(!::RubyZip::Entry.new(TEST_ZIPFILE, "dir/hello").directory?)

    assert(::RubyZip::Entry.new(TEST_ZIPFILE, "hello/").directory?)
    assert(!::RubyZip::Entry.new(TEST_ZIPFILE, "hello/").file?)

    assert(::RubyZip::Entry.new(TEST_ZIPFILE, "dir/hello/").directory?)
    assert(!::RubyZip::Entry.new(TEST_ZIPFILE, "dir/hello/").file?)
  end

  def test_equality
    entry1 = ::RubyZip::Entry.new("file.zip", "name", "isNotCompared",
                              "something extra", 123, 1234,
                              ::RubyZip::Entry::DEFLATED, 10000)
    entry2 = ::RubyZip::Entry.new("file.zip", "name", "isNotComparedXXX",
                              "something extra", 123, 1234,
                              ::RubyZip::Entry::DEFLATED, 10000)
    entry3 = ::RubyZip::Entry.new("file.zip", "name2", "isNotComparedXXX",
                              "something extra", 123, 1234,
                              ::RubyZip::Entry::DEFLATED, 10000)
    entry4 = ::RubyZip::Entry.new("file.zip", "name2", "isNotComparedXXX",
                              "something extraXX", 123, 1234,
                              ::RubyZip::Entry::DEFLATED, 10000)
    entry5 = ::RubyZip::Entry.new("file.zip", "name2", "isNotComparedXXX",
                              "something extraXX", 12, 1234,
                              ::RubyZip::Entry::DEFLATED, 10000)
    entry6 = ::RubyZip::Entry.new("file.zip", "name2", "isNotComparedXXX",
                              "something extraXX", 12, 123,
                              ::RubyZip::Entry::DEFLATED, 10000)
    entry7 = ::RubyZip::Entry.new("file.zip", "name2", "isNotComparedXXX",
                              "something extraXX", 12, 123,
                              ::RubyZip::Entry::STORED, 10000)
    entry8 = ::RubyZip::Entry.new("file.zip", "name2", "isNotComparedXXX",
                              "something extraXX", 12, 123,
                              ::RubyZip::Entry::STORED, 100000)

    assert_equal(entry1, entry1)
    assert_equal(entry1, entry2)

    assert(entry2 != entry3)
    assert(entry3 != entry4)
    assert(entry4 != entry5)
    assert(entry5 != entry6)
    assert(entry6 != entry7)
    assert(entry7 != entry8)

    assert(entry7 != "hello")
    assert(entry7 != 12)
  end

  def test_compare
    assert_equal(0, (::RubyZip::Entry.new("zf.zip", "a") <=> ::RubyZip::Entry.new("zf.zip", "a")))
    assert_equal(1, (::RubyZip::Entry.new("zf.zip", "b") <=> ::RubyZip::Entry.new("zf.zip", "a")))
    assert_equal(-1, (::RubyZip::Entry.new("zf.zip", "a") <=> ::RubyZip::Entry.new("zf.zip", "b")))

    entries = [
        ::RubyZip::Entry.new("zf.zip", "5"),
        ::RubyZip::Entry.new("zf.zip", "1"),
        ::RubyZip::Entry.new("zf.zip", "3"),
        ::RubyZip::Entry.new("zf.zip", "4"),
        ::RubyZip::Entry.new("zf.zip", "0"),
        ::RubyZip::Entry.new("zf.zip", "2")
    ]

    entries.sort!
    assert_equal("0", entries[0].to_s)
    assert_equal("1", entries[1].to_s)
    assert_equal("2", entries[2].to_s)
    assert_equal("3", entries[3].to_s)
    assert_equal("4", entries[4].to_s)
    assert_equal("5", entries[5].to_s)
  end

  def test_parentAsString
    entry1 = ::RubyZip::Entry.new("zf.zip", "aa")
    entry2 = ::RubyZip::Entry.new("zf.zip", "aa/")
    entry3 = ::RubyZip::Entry.new("zf.zip", "aa/bb")
    entry4 = ::RubyZip::Entry.new("zf.zip", "aa/bb/")
    entry5 = ::RubyZip::Entry.new("zf.zip", "aa/bb/cc")
    entry6 = ::RubyZip::Entry.new("zf.zip", "aa/bb/cc/")

    assert_equal(nil, entry1.parent_as_string)
    assert_equal(nil, entry2.parent_as_string)
    assert_equal("aa/", entry3.parent_as_string)
    assert_equal("aa/", entry4.parent_as_string)
    assert_equal("aa/bb/", entry5.parent_as_string)
    assert_equal("aa/bb/", entry6.parent_as_string)
  end

  def test_entry_name_cannot_start_with_slash
    assert_raises(::RubyZip::EntryNameError) { ::RubyZip::Entry.new("zf.zip", "/hej/der") }
  end
end
