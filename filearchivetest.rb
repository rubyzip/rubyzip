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

  def initialize(entries)
    @entries = entries
    @extractedEntries = [] # TODO: remove this, use MockFileSystem instead
  end

  def each(&aProc)
    @entries.each(&aProc)
  end

  def extractEntry(src, dst)
    getEntry(src)
    @extractedEntries << dst
    MockFileSystem.instance.createFile(dst)
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

  def entries
    @entries.keys
  end
  
  def initialize
    deleteAll
  end

  def deleteAll
    @entries = {}
  end

  def mkdir(aPath)
    dirname = Glob::FilePath.dirname(aPath)
    if (dirname.size > 0 && ! directory?(dirname))
      raise "MockFileSystem error: cannot create #{aPath}. " +
      "Directory #{Glob::FilePath.dirname(aPath)} doesn't exists" 
    end
    @entries[aPath.ensureEnd(File::SEPARATOR)] = nil
  end

  def createFile(aPath)
    @entries[aPath] = nil
  end

  def exists?(aPath)
    getEntry(aPath) != nil
  end

  def directory?(aPath)
    exists?(aPath) && getEntry(aPath).endsWith(File::SEPARATOR)
  end

  def getEntry(aPath)
    aPathReduced = aPath.ensureNotEnd(File::SEPARATOR)
    @entries.keys.find { |e| e.ensureNotEnd(File::SEPARATOR) == aPathReduced }
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
				     "dir3/dir4/entry341"])
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

  def test_expandSelection
    assert_equals([ "dir1/",
		    "dir3/"].sort,
		  @testArchive.expandSelection("*").sort)
  end

  def test_ensureDirectory
    FileArchive.ensureDirectory("hello/") { true }
    assert(MockFileSystem.instance.exists?("hello"))
    FileArchive.ensureDirectory("hello/") { false }
    assert(MockFileSystem.instance.exists?("hello"))
    assert_exception(Errno::ENOENT) {
      FileArchive.ensureDirectory("mums/") { false }
      FileArchive.ensureDirectory("mums") { false }
    }      
  end

  def test_extractAllRecursiveToDirectory
    @testArchive.extract("*", "odir1", FileArchive::RECURSIVE)
    assertExtracted([ "odir1/",
		      "odir1/dir1/",
		      "odir1/dir1/dir2/",
		      "odir1/dir1/dir2/entry121",
		      "odir1/dir1/entry11",
		      "odir1/dir3/",
		      "odir1/dir3/dir4/",
		      "odir1/dir3/dir4/entry341"])
  end

  def test_extractOneRecursiveToDirectory
    MockFileSystem.instance.mkdir("odir1")
    MockFileSystem.instance.mkdir("odir1/odir2")
    @testArchive.extract("dir1", "odir1/odir2", FileArchive::RECURSIVE)
    assertExtracted([ "odir1/",
		      "odir1/odir2/",
		      "odir1/odir2/dir1/",
		      "odir1/odir2/dir1/dir2/",
		      "odir1/odir2/dir1/dir2/entry121",
		      "odir1/odir2/dir1/entry11"])
  end

  def test_extractOneRecursiveToNewName
    @testArchive.extract("dir1", "odir1/odir2", FileArchive::RECURSIVE)
    assertExtracted([ "odir1/odir2/",
		      "odir1/odir2/dir2/",
		      "odir1/odir2/dir2/entry121",
		      "odir1/odir2/entry11"])
  end

  def test_extractOneToDirectory
    MockFileSystem.instance.mkdir("odir1")
    @testArchive.extract("dir1", "odir1")
    assertExtracted(["odir1/", "odir1/dir1/"])
  end

  def test_extractOneToNewName
    @testArchive.extract("dir1", "odir1")
    assertExtracted(["odir1/"])
  end

  def test_noMatchForSource
    assert_exception(Zip::ZipNoSuchEntryError) {
      @testArchive.extract("noMatchForThis*", "outdir", FileArchive::RECURSIVE)
    }
  end

  def assertExtracted(expectedExtractedEntries)
    assert_equals(expectedExtractedEntries.sort, MockFileSystem.instance.entries.sort)
  end

end

