#!/usr/bin/env ruby

$VERBOSE = true

require 'rubyunit'
require 'filearchive'


class GlobTest < RUNIT::TestCase

  def test_expandPath
    assert_equals([], 
		  Glob.expandPath(""))
    assert_equals(["rip"], 
		  Glob.expandPath("rip"))
    assert_equals(["rip/"], 
		  Glob.expandPath("rip/"))
    assert_equals(["rip/", "rip/rap/", "rip/rap/rup"], 
		  Glob.expandPath("rip/rap/rup"))
    assert_equals(["rip/", "rip/rap/", "rip/rap/rup/"], 
		  Glob.expandPath("rip/rap/rup/"))
  end

  def test_expandPathList
    assert_equals(["rip/", "rip/rap/", "rip/rap/rup", "jimmy/", "jimmy/benny"].sort,
		  Glob.expandPathList(["rip/rap/rup", "jimmy/benny"]).sort)
    assert_equals(["rip", "rip/", "rip/rap/", "rip/rap/rup", "jimmy/", "jimmy/benny/"].sort,
		  Glob.expandPathList(["rip/rap/rup", "jimmy/benny/", "rip"]).sort)
    assert_equals([], Glob.expandPathList([]))
  end

  FILE_LIST = [ "rip/rap/rup", "jimmy/benny/", "maria/jenny", "rip/tom", "marie/ben" ]

  def test_globSimple
    assert_equals(["rip/"], Glob.glob(FILE_LIST, "rip/"))
    assert_equals([], Glob.glob(["rip"], "rip/"))
  end

  def test_globQuestionMark
    assert_equals(["rip/"], Glob.glob(FILE_LIST, "ri?"))
    assert_equals(["maria/", "marie/"].sort, Glob.glob(FILE_LIST, "mari?").sort)
    assert_equals([].sort, Glob.glob(FILE_LIST, "mari??").sort)
    assert_equals(["maria/", "marie/"].sort, Glob.glob(FILE_LIST, "mar??").sort)
    assert_equals(["maria/jenny"].sort, Glob.glob(FILE_LIST, "maria/jenn?").sort)
    assert_equals(["marie/"], Glob.glob(FILE_LIST, "ma??e").sort)
    assert_equals([], Glob.glob(FILE_LIST, "marie/?").sort)
  end

  def test_globStar
    assert_equals(["maria/", "marie/"].sort, Glob.glob(FILE_LIST, "m*").sort)
    assert_equals(["rip/"], Glob.glob(FILE_LIST, "rip*").sort)
    assert_equals(["rip/rap/", "rip/tom"].sort, Glob.glob(FILE_LIST, "rip/*").sort)
    assert_equals(["rip/rap/", "rip/tom"].sort, Glob.glob(FILE_LIST, "r*/*").sort)
  end

  def test_combined
    assert_equals(["rip/rap/"], Glob.glob(FILE_LIST, "r*/ra?").sort)
  end
  
end


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
    entry = @entries.find { |e| e == src }
    if (entry == nil)
      throw StandardError, "'#{src}' not found in #{@entries.join(", ")}"
    end
    entry
  end

  def extractedEntries
    @extractedEntries
  end
end

class MockFileSystem
  include Singleton

  def initialize
    deleteAll
  end

  def deleteAll
    @entries = {}
  end

  def mkdir(aPath)
    @entries[aPath] = nil
  end

  def exists?(aPath)
    @entries.include?(aPath)
  end

  def directory?(aPath)
    exists?(aPath) && aPath.endsWith(File::SEPARATOR)
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
    configureMockFileSystem
  end

  def teardown
    unconfigureMockFileSystem
  end

  def configureMockFileSystem
    MockFileSystem.instance.deleteAll

    class << Dir
      alias :origMkdir :mkdir
      
      def mkdir(aPath)
	MockFileSystem.instance.mkdir(aPath)
      end
    end

    class << File
      alias :origExists? :exists?
      alias :origDirectory? :directory?
      
      def exists?(aPath)
	MockFileSystem.instance.exists?(aPath)
      end

      def directory?(aPath)
	MockFileSystem.instance.directory?(aPath)
      end
    end
  end

  def unconfigureMockFileSystem
    class << Dir
      alias :mkdir :origMkdir
    end
    class << File
      alias :exists? :origExists?
      alias :directory? :origDirectory?
    end
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
    assert_equals(expectedExtractedEntries.sort, testArchive.extractedEntries.sort)
  end

end
