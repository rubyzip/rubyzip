#!/usr/bin/env ruby

$VERBOSE = true

require 'rubyunit'
require 'filearchive'

class TestArchive
  include Enumerable
  include FileArchive

  def initialize(entries, fakeKnownDirectories)
    @entries = entries
    @fakeKnownDirectories = fakeKnownDirectories
    @extractedEntries = []
  end

  def each(&aProc)
    @entries.each(&aProc)
  end

  def extractEntry(src, dst)
    getEntry(src)
    @extractedEntries << dst
  end

  def getEntry(src)
    entry = @entries.find { 
      |e| 
      Glob.pruneLeadingAndTrailingSeparator(e) == src
    }
    if (entry == nil)
      throw StandardError, "'#{src}' not found in #{@entries.join(", ")}"
    end
    entry
  end

  def extractedEntries
    @extractedEntries
  end
end

class FileArchiveTest < RUNIT::TestCase
  def setup
    @testArchive = TestArchive.new([ "dir1/",
				     "dir1/dir2/",
				     "dir1/dir2/entry121",
				     "dir1/entry11",
				     "dir3/",
				     "dir3/dir4/",
				     "dir3/dir4/entry341"],
				   [ "odir1/", 
				     "odir1/odir2/", 
				     "odir3/"])
  end

  def test_extractAllRecursiveToDirectory
    @testArchive.extract("*", "odir1", FileArchive::RECURSIVE)
    assertExtracted([ "odir1/dir1/dir2/",
		      "odir1/dir1/dir2/entry121",
		      "odir1/dir1/entry11",
		      "odir1/dir3/dir4/entry341"])
  end

  def test_extractAllRecursiveToNewName
    @testArchive.extract("*", "newName", FileArchive::RECURSIVE)
    assertExtracted([ "newName/dir1/dir2/",
		      "newName/dir1/dir2/entry121",
		      "newName/dir1/entry11",
		      "newName/dir3/dir4/entry341"])
  end

  def test_extractOneRecursiveToDirectory
    @testArchive.extract("dir1", "odir1/odir2", FileArchive::RECURSIVE)
    assertExtracted([ "odir1/odir2/dir1/dir2/",
		      "odir1/odir2/dir1/dir2/entry121",
		      "odir1/odir2/dir1/entry11"])
  end

  def test_extractOneRecursiveToNewName
    @testArchive.extract("dir1", "newName", FileArchive::RECURSIVE)
    assertExtracted([ "newName/dir2/",
		      "newName/dir2/entry121",
		      "newName/entry11"])
  end

  def test_extractOneToDirectory
    @testArchive.extract("dir1", "odir1")
    assertExtracted(["odir1/dir1"])
  end

  def test_extractOneToNewName
    @testArchive.extract("dir1", "newName")
    assertExtracted(["newname"])
  end

  def test_noMatchForSource
    assert_exception(Zip::ZipNoSuchEntryError) {
      @testArchive.extract("noMatchForThis*", "outdir", FileArchive::RECURSIVE)
    }
  end

  def assertExtracted(expectedExtractedEntries, testArchive = @testArchive)
    expected = expectedExtractedEntries.sort.map {
      |e|
      Glob.pruneLeadingAndTrailingSeparator(e)
    }
    actual = testArchive.extractedEntries.sort.map {
      |e|
      Glob.pruneLeadingAndTrailingSeparator(e)
    }
    assert_equals(expected, actual)
  end

end
