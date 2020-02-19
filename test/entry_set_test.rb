require 'test_helper'

class ZipEntrySetTest < MiniTest::Test
  ZIP_ENTRIES = [
    ::Zip::Entry.new('zipfile.zip', 'name1', 'comment1'),
    ::Zip::Entry.new('zipfile.zip', 'name3', 'comment1'),
    ::Zip::Entry.new('zipfile.zip', 'name2', 'comment1'),
    ::Zip::Entry.new('zipfile.zip', 'name4', 'comment1'),
    ::Zip::Entry.new('zipfile.zip', 'name5', 'comment1'),
    ::Zip::Entry.new('zipfile.zip', 'name6', 'comment1')
  ]

  def setup
    @zip_entry_set = ::Zip::EntrySet.new(ZIP_ENTRIES)
  end

  def teardown
    ::Zip.reset!
  end

  def test_include
    assert(@zip_entry_set.include?(ZIP_ENTRIES.first))
    assert(!@zip_entry_set.include?(::Zip::Entry.new('different.zip', 'different', 'aComment')))
  end

  def test_size
    assert_equal(ZIP_ENTRIES.size, @zip_entry_set.size)
    assert_equal(ZIP_ENTRIES.size, @zip_entry_set.length)
    @zip_entry_set << ::Zip::Entry.new('a', 'b', 'c')
    assert_equal(ZIP_ENTRIES.size + 1, @zip_entry_set.length)
  end

  def test_add
    zes = ::Zip::EntrySet.new
    entry1 = ::Zip::Entry.new('zf.zip', 'name1')
    entry2 = ::Zip::Entry.new('zf.zip', 'name2')
    zes << entry1
    assert(zes.include?(entry1))
    zes.push(entry2)
    assert(zes.include?(entry2))
  end

  def test_delete
    assert_equal(ZIP_ENTRIES.size, @zip_entry_set.size)
    entry = @zip_entry_set.delete(ZIP_ENTRIES.first)
    assert_equal(ZIP_ENTRIES.size - 1, @zip_entry_set.size)
    assert_equal(ZIP_ENTRIES.first, entry)

    entry = @zip_entry_set.delete(ZIP_ENTRIES.first)
    assert_equal(ZIP_ENTRIES.size - 1, @zip_entry_set.size)
    assert_nil(entry)
  end

  def test_each
    # Used each instead each_with_index due the bug in jRuby
    count = 0
    @zip_entry_set.each do |entry|
      assert(ZIP_ENTRIES.include?(entry))
      count += 1
    end
    assert_equal(ZIP_ENTRIES.size, count)
  end

  def test_entries
    assert_equal(ZIP_ENTRIES, @zip_entry_set.entries)
  end

  def test_find_entry
    entries = [::Zip::Entry.new('zipfile.zip', 'MiXeDcAsEnAmE', 'comment1')]

    ::Zip.case_insensitive_match = true
    zip_entry_set = ::Zip::EntrySet.new(entries)
    assert_equal(entries[0], zip_entry_set.find_entry('MiXeDcAsEnAmE'))
    assert_equal(entries[0], zip_entry_set.find_entry('mixedcasename'))

    ::Zip.case_insensitive_match = false
    zip_entry_set = ::Zip::EntrySet.new(entries)
    assert_equal(entries[0], zip_entry_set.find_entry('MiXeDcAsEnAmE'))
    assert_nil(zip_entry_set.find_entry('mixedcasename'))
  end

  def test_entries_with_sort
    ::Zip.sort_entries = true
    assert_equal(ZIP_ENTRIES.sort, @zip_entry_set.entries)
    ::Zip.sort_entries = false
    assert_equal(ZIP_ENTRIES, @zip_entry_set.entries)
  end

  def test_entries_sorted_in_each
    ::Zip.sort_entries = true
    arr = []
    @zip_entry_set.each do |entry|
      arr << entry
    end
    assert_equal(ZIP_ENTRIES.sort, arr)
  end

  def test_compound
    new_entry = ::Zip::Entry.new('zf.zip', 'new entry', "new entry's comment")
    assert_equal(ZIP_ENTRIES.size, @zip_entry_set.size)
    @zip_entry_set << new_entry
    assert_equal(ZIP_ENTRIES.size + 1, @zip_entry_set.size)
    assert(@zip_entry_set.include?(new_entry))

    @zip_entry_set.delete(new_entry)
    assert_equal(ZIP_ENTRIES.size, @zip_entry_set.size)
  end

  def test_dup
    copy = @zip_entry_set.dup
    assert_equal(@zip_entry_set, copy)

    # demonstrate that this is a deep copy
    copy.entries[0].name = 'a totally different name'
    assert(@zip_entry_set != copy)
  end

  def test_parent
    entries = [
      ::Zip::Entry.new('zf.zip', 'a/'),
      ::Zip::Entry.new('zf.zip', 'a/b/'),
      ::Zip::Entry.new('zf.zip', 'a/b/c/')
    ]
    entry_set = ::Zip::EntrySet.new(entries)

    assert_nil(entry_set.parent(entries[0]))
    assert_equal(entries[0], entry_set.parent(entries[1]))
    assert_equal(entries[1], entry_set.parent(entries[2]))
  end

  def test_glob
    res = @zip_entry_set.glob('name[2-4]')
    assert_equal(3, res.size)
    assert_equal(ZIP_ENTRIES[1, 3].sort, res.sort)
  end

  def test_glob2
    entries = [
      ::Zip::Entry.new('zf.zip', 'a/'),
      ::Zip::Entry.new('zf.zip', 'a/b/b1'),
      ::Zip::Entry.new('zf.zip', 'a/b/c/'),
      ::Zip::Entry.new('zf.zip', 'a/b/c/c1')
    ]
    entry_set = ::Zip::EntrySet.new(entries)

    assert_equal(entries[0, 1], entry_set.glob('*'))
    # assert_equal(entries[FIXME], entry_set.glob("**"))
    # res = entry_set.glob('a*')
    # assert_equal(entries.size, res.size)
    # assert_equal(entry_set.map { |e| e.name }, res.map { |e| e.name })
  end

  def test_glob3
    entries = [
      ::Zip::Entry.new('zf.zip', 'a/a'),
      ::Zip::Entry.new('zf.zip', 'a/b'),
      ::Zip::Entry.new('zf.zip', 'a/c')
    ]
    entry_set = ::Zip::EntrySet.new(entries)

    assert_equal(entries[0, 2].sort, entry_set.glob('a/{a,b}').sort)
  end
end
