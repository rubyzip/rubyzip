require 'test_helper'

class ZipEntrySetTest < MiniTest::Unit::TestCase
  ZIP_ENTRIES = [
      ::RubyZip::Entry.new("zipfile.zip", "name1", "comment1"),
      ::RubyZip::Entry.new("zipfile.zip", "name3", "comment1"),
      ::RubyZip::Entry.new("zipfile.zip", "name2", "comment1"),
      ::RubyZip::Entry.new("zipfile.zip", "name4", "comment1"),
      ::RubyZip::Entry.new("zipfile.zip", "name5", "comment1"),
      ::RubyZip::Entry.new("zipfile.zip", "name6", "comment1")
  ]

  def setup
    @zipEntrySet = ::RubyZip::EntrySet.new(ZIP_ENTRIES)
  end

  def test_include
    assert(@zipEntrySet.include?(ZIP_ENTRIES.first))
    assert(!@zipEntrySet.include?(::RubyZip::Entry.new("different.zip", "different", "aComment")))
  end

  def test_size
    assert_equal(ZIP_ENTRIES.size, @zipEntrySet.size)
    assert_equal(ZIP_ENTRIES.size, @zipEntrySet.length)
    @zipEntrySet << ::RubyZip::Entry.new("a", "b", "c")
    assert_equal(ZIP_ENTRIES.size + 1, @zipEntrySet.length)
  end

  def test_add
    zes = ::RubyZip::EntrySet.new
    entry1 = ::RubyZip::Entry.new("zf.zip", "name1")
    entry2 = ::RubyZip::Entry.new("zf.zip", "name2")
    zes << entry1
    assert(zes.include?(entry1))
    zes.push(entry2)
    assert(zes.include?(entry2))
  end

  def test_delete
    assert_equal(ZIP_ENTRIES.size, @zipEntrySet.size)
    entry = @zipEntrySet.delete(ZIP_ENTRIES.first)
    assert_equal(ZIP_ENTRIES.size - 1, @zipEntrySet.size)
    assert_equal(ZIP_ENTRIES.first, entry)

    entry = @zipEntrySet.delete(ZIP_ENTRIES.first)
    assert_equal(ZIP_ENTRIES.size - 1, @zipEntrySet.size)
    assert_nil(entry)
  end

  def test_each
    # Used each instead each_with_index due the bug in jRuby
    count = 0
    @zipEntrySet.each do |entry|
      assert(ZIP_ENTRIES.include?(entry))
      count += 1
    end
    assert_equal(ZIP_ENTRIES.size, count)
  end

  def test_entries
    assert_equal(ZIP_ENTRIES, @zipEntrySet.entries)
  end

  def test_entries_with_sort
    ::RubyZip.sort_entries = true
    assert_equal(ZIP_ENTRIES.sort, @zipEntrySet.entries)
    ::RubyZip.sort_entries = false
    assert_equal(ZIP_ENTRIES, @zipEntrySet.entries)
  end

  def test_compound
    newEntry = ::RubyZip::Entry.new("zf.zip", "new entry", "new entry's comment")
    assert_equal(ZIP_ENTRIES.size, @zipEntrySet.size)
    @zipEntrySet << newEntry
    assert_equal(ZIP_ENTRIES.size + 1, @zipEntrySet.size)
    assert(@zipEntrySet.include?(newEntry))

    @zipEntrySet.delete(newEntry)
    assert_equal(ZIP_ENTRIES.size, @zipEntrySet.size)
  end

  def test_dup
    copy = @zipEntrySet.dup
    assert_equal(@zipEntrySet, copy)

    # demonstrate that this is a deep copy
    copy.entries[0].name = "a totally different name"
    assert(@zipEntrySet != copy)
  end

  def test_parent
    entries = [
        ::RubyZip::Entry.new("zf.zip", "a/"),
        ::RubyZip::Entry.new("zf.zip", "a/b/"),
        ::RubyZip::Entry.new("zf.zip", "a/b/c/")
    ]
    entrySet = ::RubyZip::EntrySet.new(entries)

    assert_equal(nil, entrySet.parent(entries[0]))
    assert_equal(entries[0], entrySet.parent(entries[1]))
    assert_equal(entries[1], entrySet.parent(entries[2]))
  end

  def test_glob
    res = @zipEntrySet.glob('name[2-4]')
    assert_equal(3, res.size)
    assert_equal(ZIP_ENTRIES[1, 3].sort, res.sort)
  end

  def test_glob2
    entries = [
        ::RubyZip::Entry.new("zf.zip", "a/"),
        ::RubyZip::Entry.new("zf.zip", "a/b/b1"),
        ::RubyZip::Entry.new("zf.zip", "a/b/c/"),
        ::RubyZip::Entry.new("zf.zip", "a/b/c/c1")
    ]
    entrySet = ::RubyZip::EntrySet.new(entries)

    assert_equal(entries[0, 1], entrySet.glob("*"))
#    assert_equal(entries[FIXME], entrySet.glob("**"))
#    res = entrySet.glob('a*')
#    assert_equal(entries.size, res.size)
#    assert_equal(entrySet.map { |e| e.name }, res.map { |e| e.name })
  end
end
