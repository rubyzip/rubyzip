#!/usr/bin/env ruby

$VERBOSE = true

require 'rubyunit'
require 'filearchive'
require 'fileutils'

class StringExtensionsTest < RUNIT::TestCase
  def test_endsWith
    assert("hello".endsWith("o"))
    assert("hello".endsWith("lo"))
    assert("hello".endsWith("hello"))
    assert(!"howdy".endsWith("o"))
    assert(!"howdy".endsWith("oy"))
    assert(!"howdy".endsWith("howdy doody"))
    assert(!"howdy".endsWith("doody howdy"))
  end

  def test_ensureEnd
    assert_equals("hello!", "hello!".ensureEnd("!"))
    assert_equals("hello!", "hello!".ensureEnd("o!"))
    assert_equals("hello!", "hello".ensureEnd("!"))
    assert_equals("hello!", "hel".ensureEnd("lo!"))
  end
end

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

  def initialize(entries = [])
    @entries = entries
  end

  def each(&aProc)
    @entries.each(&aProc)
  end

  def extractEntry(src, dst, &continueOnExists)
    continueOnExists ||= proc { false }
    getEntry(src)
    if (MockFileSystem.instance.exists?(dst) && ! continueOnExists.call(dst))
      raise Errno::EEXIST, "File exists - \"#{dst}\""
    end
    MockFileSystem.instance.createFile(dst)
  end

  def addEntry(src, dst)
    @entries << dst
  end

  def getEntry(src)
    entry = @entries.find { |e| e == src }
    if (entry == nil)
      throw StandardError, "'#{src}' not found in #{@entries.join(", ")}"
    end
    entry
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
    aPathReduced = aPath.chomp(File::SEPARATOR)
    @entries.keys.find { |e| e.chomp(File::SEPARATOR) == aPathReduced }
  end
end

module MockFileSystemTestSetup
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
end

module FileArchiveTestFixture
  include MockFileSystemTestSetup

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
 
end

class FileArchiveTest < RUNIT::TestCase
  include FileArchiveTestFixture

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

  def test_mkdir
    fail "implement"
  end
end

class FileArchiveExtractTest < RUNIT::TestCase
  include FileArchiveTestFixture

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

  def test_extractNoMatchForSource
    assert_exception(Errno::ENOENT) {
      @testArchive.extract("noMatchForThis*", "outdir", FileArchive::RECURSIVE)
    }
  end
  
  def test_extractContinueOnExistsProc
    procArg = nil
    MockFileSystem.instance.createFile("myfile")
    @testArchive.extract("dir1/dir2/entry121", "myfile", FileArchive::RECURSIVE,
			 proc { |filename| procArg = filename; true})
    assert_equals("myfile", procArg)
    
    assert_exception(Errno::EEXIST) {
      @testArchive.extract("dir1/dir2/entry121", "myfile", proc { false })
    }
  end

  def test_extractRegex
    @testArchive.extract(/entry/, "odir")

    expectedOutput = ["odir/entry11", "odir/entry121", "odir/entry341"]
    expectedOutput.each { 
      |filename| 
      assert(MockFileSystem.instance.exists?(filename), 
	     "filename #{filename} must exist. "+
	     "Filesystem contains:\n#{MockFileSystem.instance.entries.join($/)}")
    }
  end

  def test_extractList
    @testArchive.extract(["dir1/dir2/entry121", "dir3/dir4/entry341"], 
			 "odir", FileArchive::RECURSIVE)
    assert(MockFileSystem.instance.exists?("odir/entry121"))
    assert(MockFileSystem.instance.exists?("odir/entry341"))
  end

  def test_extractCreateDestDirProc
    procArg = nil
    @testArchive.extract(["dir1/dir2/entry121", "dir3/dir4/entry341"], 
			 "odir", FileArchive::RECURSIVE, 
			 proc { false }, 
			 proc { |directoryname| procArg = directoryname; true })
    assert_equals("odir", procArg)
    assert(MockFileSystem.instance.exists?("odir"))
    
  end

  def assertExtracted(expectedExtractedEntries)
    assert_equals(expectedExtractedEntries.sort, MockFileSystem.instance.entries.sort)
  end

end

class FileArchiveAddTest < RUNIT::TestCase
  include MockFileSystemTestSetup

  def setup
    @testArchive = TestArchive.new
    MockFileSystem.instance.deleteAll
    MockFileSystem.instance.createFile("dir1/file11")
    MockFileSystem.instance.createFile("dir1/file12")
    MockFileSystem.instance.createFile("dir1/file13")
    MockFileSystem.instance.createFile("dir1/file14")
    MockFileSystem.instance.createFile("dir1/dir2/file121")
    MockFileSystem.instance.createFile("dir1/dir2/file122")
    MockFileSystem.instance.createFile("dir1/dir2/file123")
    MockFileSystem.instance.createFile("dir1/dir3/file131")

    configureMockFileSystem
  end

  def teardown
    unconfigureMockFileSystem
  end

  def test_addSingleFile
    @testArchive.add("dir1/file11", "")
    assert(@testArchive.entries.include?("file11"))

    @testArchive.add("dir1/file11", "newname")
    assert(@testArchive.entries.include?("newname"))
  end

  def test_addAllRecursively
    @testArchive.mkdir("existing")
    @testArchive.add("dir1", "existing", FileArchive::RECURSIVE)
    assert(@testArchive.include?("existing/dir1/file11"))
    assert(@testArchive.include?("existing/dir1/file12"))
    assert(@testArchive.include?("existing/dir1/file13"))
    assert(@testArchive.include?("existing/dir1/file14"))
    assert(@testArchive.include?("existing/dir1/dir2/file121"))
    assert(@testArchive.include?("existing/dir1/dir2/file122"))
    assert(@testArchive.include?("existing/dir1/dir2/file123"))
    assert(@testArchive.include?("existing/dir1/dir3/file131"))
  end

  def test_addSubDirRecursively
    fail "implement"
  end

  def test_addRecursivelyToExistingDirectory
  end

  def test_addMultipleWithFilenameGlobbing
    fail "implement"
  end

  def test_addMultipleWithFilenameGlobbingRecursively
    fail "implement"
  end
end

class FileArchiveTestFiles

  TEST_DIRECTORIES = [ 
    "aDir", 
    "aDir/aChildDir", 
    "aDir/aChildDir/aSecondChildDir"
  ]
  
  TEST_REGULAR_FILES = [ 
    "aDir/file1", 
    "aDir/aChildDir/file2", 
    "aDir/aChildDir/file3", 
    "aDir/aChildDir/aSecondChildDir/file4"
  ]

  TEST_FILES = TEST_DIRECTORIES + TEST_REGULAR_FILES

  def self.create
    TEST_FILES.each { |f| FileUtils.rm_rf f }
    TEST_DIRECTORIES.sort.each { |d| Dir.mkdir d }
    TEST_REGULAR_FILES.each { 
      |filename|
      File.open(filename, "w") { |f| f << "Test file '#{filename}'" }
    }
  end
end

END {
  # before running the tests
  if __FILE__ == $0
    Dir.chdir "test"
  end
  
  FileArchiveTestFiles.create
}
