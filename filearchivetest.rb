#!/usr/bin/env ruby

$VERBOSE = true

require 'rubyunit'
require 'filearchive'
require 'zip'

class TestArchive
  include Enumerable
  include FileArchive

  def initialize(entries, fakeKnownDirectories)
    @entries = Glob.expandPathList(entries)
    @fakeKnownDirectories = fakeKnownDirectories
  end

  def each(&aProc)
    @entries.each(&aProc)
  end

  def extractedEntries
    []
  end
end

class FileArchiveTest < RUNIT::TestCase
  def setup
    @testArchive = TestArchive.new([ "dir1/dir2/",
				     "dir1/dir2/entry121",
				     "dir1/entry11",
				     "dir3/dir4/entry341"],
				   [ "odir1", 
				     "odir1/odir2", 
				     "odir3"])
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

  def assertExtracted(expectedExtractedEntries, testArchive = @testArchive)
    assert_equals(expectedExtractedEntries.sort,
		  testArchive.extractedEntries.sort)
  end
end
