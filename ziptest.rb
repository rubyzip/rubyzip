#!/usr/bin/env ruby

require 'runit/testcase'
require 'runit/cui/testrunner'
require 'zip'

class PseudoIOTest < RUNIT::TestCase
  # PseudoIO subclass that provides a read method
  
  TEST_LINES = [ "Hello world#{$/}", 
    "this is the second line#{$/}", 
    "this is the last line"]
  TEST_STRING = TEST_LINES.join
  class TestPseudoIO 
    include PseudoIO
    def initialize(aString)
      @contents = aString
      @readPointer = 0
    end

    def read(charsToRead)
      retVal=@contents[@readPointer, charsToRead]
      @readPointer+=charsToRead
      return retVal
    end

    def produceInput
      read(100)
    end

    def inputFinished?
      @contents[@readPointer] == nil
    end
  end

  def setup
    @io = TestPseudoIO.new(TEST_STRING)
  end
  
  def test_gets
    assert_equals(TEST_LINES[0], @io.gets)
    assert_equals(TEST_LINES[1], @io.gets)
    assert_equals(TEST_LINES[2], @io.gets)
    assert_equals(nil, @io.gets)
  end

  def test_getsMultiCharSeperator
    assert_equals("Hell", @io.gets("ll"))
    assert_equals("o world#{$/}this is the second l", @io.gets("d l"))
  end

  def test_each_line
    lineNumber=0
    @io.each_line {
      |line|
      assert_equals(TEST_LINES[lineNumber], line)
      lineNumber+=1
    }
  end

  def test_readlines
    assert_equals(TEST_LINES, @io.readlines)
  end

  def test_readline
    test_gets
    begin
      @io.readline
      fail "EOFError expected"
      rescue EOFError
    end
  end
end

class ZipEntryTest < RUNIT::TestCase
  TEST_COMMENT = "a comment"
  TEST_COMPRESSED_SIZE = 1234
  TEST_CRC = 325324
  TEST_EXTRA = "Some data here"
  TEST_COMPRESSIONMETHOD = ZipEntry::DEFLATED
  TEST_NAME = "entry name"
  TEST_SIZE = 8432
  TEST_ISDIRECTORY = false

  def test_constructorAndGetters
    entry = ZipEntry.new(TEST_COMMENT,
			 TEST_COMPRESSED_SIZE,
			 TEST_CRC,
			 TEST_EXTRA,
			 TEST_COMPRESSIONMETHOD,
			 TEST_NAME,
			 TEST_SIZE)

    assert_equals(TEST_COMMENT, entry.comment)
    assert_equals(TEST_COMPRESSED_SIZE, entry.compressedSize)
    assert_equals(TEST_CRC, entry.crc)
    assert_equals(TEST_EXTRA, entry.extra)
    assert_equals(TEST_COMPRESSIONMETHOD, entry.compressionMethod)
    assert_equals(TEST_NAME, entry.name)
    assert_equals(TEST_SIZE, entry.size)
    assert_equals(TEST_ISDIRECTORY, entry.isDirectory)
  end
end

class ZipLocalEntryTest < RUNIT::TestCase
  def test_ReadLocalEntryHeaderOfFirstTestZipEntry
    File.open(TestZipFile::TEST_ZIP3.zipName) {
      |file|
      entry = ZipLocalEntry.readFromStream(file)
      
      assert_equal(nil, entry.comment)
      # Differs from windows and unix because of CR LF
      # assert_equal(480, entry.compressedSize)
      # assert_equal(0x2a27930f, entry.crc)
      # extra field is 21 bytes long
      # probably contains some unix attrutes or something
      # disabled: assert_equal(nil, entry.extra)
      assert_equal(ZipEntry::DEFLATED, entry.compressionMethod)
      assert_equal(TestZipFile::TEST_ZIP3.entryNames[0], entry.name)
      assert_equal(File.size(TestZipFile::TEST_ZIP3.entryNames[0]), entry.size)
      assert(! entry.isDirectory)
    }
  end
  def test_ReadLocalEntryFromNonZipFile
    File.open("ziptest.rb") {
      |file|
      ZipLocalEntry.readFromStream(file)
    }
    fail "Excepted exception"
    rescue
  end
end
 
module AssertEntry
  def assertNextEntry(filename, zis)
    assertEntry(filename, zis, zis.getNextEntry.name)
  end

  def assertEntry(filename, zis, entryName)
    assert_equals(filename, entryName)
    File.open(filename, "rb") {
      |file|
      expected = file.read
      actual   = zis.read
      if (expected != actual)
	if (expected.length > 400 || actual.length > 400)
	  zipEntryFilename=entryName+".zipEntry"
	  File.open(zipEntryFilename, "wb") { |file| file << actual }
	  fail("File '#{filename}' is different from '#{zipEntryFilename}'")
	else
	  assert_equals(expected, actual)
	end
      end
    }
  end
end

class ZipInputStreamTest < RUNIT::TestCase
  include AssertEntry

  def test_new
    zis = ZipInputStream.new(TestZipFile::TEST_ZIP2.zipName)
    assertTestfileContents(zis)
    zis.close    
  end

  def test_openWithBlock
    ZipInputStream.open(TestZipFile::TEST_ZIP2.zipName) {
      |zis|
      assertTestfileContents(zis)
    }
  end

  def test_openWithoutBlock
    zis = ZipInputStream.open(TestZipFile::TEST_ZIP2.zipName)
    assertTestfileContents(zis)
  end

  def test_incompleteReads
    ZipInputStream.open(TestZipFile::TEST_ZIP2.zipName) {
      |zis|
      entry = zis.getNextEntry
      assert_equals(TestZipFile::TEST_ZIP2.entryNames[0], entry.name)
      assert zis.gets.length > 0
      entry = zis.getNextEntry
      assert_equals(TestZipFile::TEST_ZIP2.entryNames[1], entry.name)
      assert_equals(0, entry.size)
      assert_equals(nil, zis.gets)
      entry = zis.getNextEntry
      assert_equals(TestZipFile::TEST_ZIP2.entryNames[2], entry.name)
      assert zis.gets.length > 0
      entry = zis.getNextEntry
      assert_equals(TestZipFile::TEST_ZIP2.entryNames[3], entry.name)
      assert zis.gets.length > 0
    }
  end
  
  private
  
  def assertTestfileContents(zis)
    assert(zis != nil)
    assertNextEntry(TestZipFile::TEST_ZIP2.entryNames[0], zis)
    assertNextEntry(TestZipFile::TEST_ZIP2.entryNames[1], zis)
    assertNextEntry(TestZipFile::TEST_ZIP2.entryNames[2], zis)
    assertNextEntry(TestZipFile::TEST_ZIP2.entryNames[3], zis)
    assert_equals(nil, zis.getNextEntry)
  end    
end


# For representation and creation of
# test data
class TestZipFile
  attr_reader :zipName, :entryNames, :comment

  def initialize(zipName, entryNames, comment = "")
    @zipName=zipName
    @entryNames=entryNames
    @comment = comment
    @@testZips << self
  end

  def TestZipFile.testZips
    @@testZips
  end

  @@testZips = []

  def TestZipFile.createTestZips(recreate)
    files = Dir.entries(".")
    if (recreate || 
	    ! (files.index(TEST_ZIP1.zipName) &&
	       files.index(TEST_ZIP2.zipName) &&
	       files.index(TEST_ZIP3.zipName) &&
	       files.index("empty.txt")      &&
	       files.index("short.txt")      &&
	       files.index("longAscii.txt")  &&
	       files.index("longBinary.bin") ))
      raise "failed to create test zip '#{TEST_ZIP1.zipName}'" unless 
	system("zip #{TEST_ZIP1.zipName} ziptest.rb")
      raise "failed to remove entry from '#{TEST_ZIP1.zipName}'" unless 
	system("zip #{TEST_ZIP1.zipName} -d ziptest.rb")
      
      File.open("empty.txt", "w") {}
      
      File.open("short.txt", "w") { |file| file << "ABCDEF" }
      ziptestTxt=""
      File.open("ziptest.rb") { |file| ziptestTxt=file.read }
      File.open("longAscii.txt", "w") {
	|file|
	while (file.tell < 1E5)
	  file << ziptestTxt
	end
      }
      
      testBinaryPattern=""
      File.open("empty.zip") { |file| testBinaryPattern=file.read }
      testBinaryPattern *= 4
      
      File.open("longBinary.bin", "wb") {
	|file|
	while (file.tell < 1E6)
	  file << testBinaryPattern << rand
	end
      }
      raise "failed to create test zip '#{TEST_ZIP2.zipName}'" unless 
	system("zip #{TEST_ZIP2.zipName} #{TEST_ZIP2.entryNames.join(' ')}")
      raise "failed to add comment to test zip '#{TEST_ZIP2.zipName}'" unless 
	system("echo '#{TEST_ZIP2.comment}' | zip #{TEST_ZIP2.zipName}")

      raise "failed to create test zip '#{TEST_ZIP3.zipName}'" unless 
	system("zip #{TEST_ZIP3.zipName} #{TEST_ZIP3.entryNames.join(' ')}")
    end
  end

  TEST_ZIP1 = TestZipFile.new("empty.zip", [])
  TEST_ZIP2 = TestZipFile.new("4entry.zip", %w{ longAscii.txt empty.txt short.txt longBinary.bin})
  TEST_ZIP3 = TestZipFile.new("test1.zip", %w{ file1.txt })
end

module Enumerable
  def compareEnumerables(otherEnumerable)
    otherAsArray = otherEnumerable.to_a
    index=0
    each_with_index {
      |element, index|
      return false unless yield (element, otherAsArray[index])
    }
    return index+1 == otherAsArray.size
  end
end


class ZipCentralDirectoryEntryTest < RUNIT::TestCase

  def test_readFromStream
    File.open("testDirectory.bin", "rb") {
      |file|
      entry = ZipCentralDirectoryEntry.readFromStream(file)
      
      assert_equals("longAscii.txt", entry.name)
      assert_equals(ZipEntry::DEFLATED, entry.compressionMethod)
      assert_equals(106490, entry.size)
      assert_equals(3784, entry.compressedSize)
      assert_equals(0xfcd1799c, entry.crc)
      assert_equals("", entry.comment)

      entry = ZipCentralDirectoryEntry.readFromStream(file)
      assert_equals("empty.txt", entry.name)
      assert_equals(ZipEntry::STORED, entry.compressionMethod)
      assert_equals(0, entry.size)
      assert_equals(0, entry.compressedSize)
      assert_equals(0x0, entry.crc)
      assert_equals("", entry.comment)

      entry = ZipCentralDirectoryEntry.readFromStream(file)
      assert_equals("short.txt", entry.name)
      assert_equals(ZipEntry::STORED, entry.compressionMethod)
      assert_equals(6, entry.size)
      assert_equals(6, entry.compressedSize)
      assert_equals(0xbb76fe69, entry.crc)
      assert_equals("", entry.comment)

      entry = ZipCentralDirectoryEntry.readFromStream(file)
      assert_equals("longBinary.bin", entry.name)
      assert_equals(ZipEntry::DEFLATED, entry.compressionMethod)
      assert_equals(1000024, entry.size)
      assert_equals(70847, entry.compressedSize)
      assert_equals(0x10da7d59, entry.crc)
      assert_equals("", entry.comment)

      entry = ZipCentralDirectoryEntry.readFromStream(file)
      assert_equals(nil, entry)
# Fields that are not check by this test:
#          version made by                 2 bytes
#          version needed to extract       2 bytes
#          general purpose bit flag        2 bytes
#          last mod file time              2 bytes
#          last mod file date              2 bytes
#          compressed size                 4 bytes
#          uncompressed size               4 bytes
#          disk number start               2 bytes
#          internal file attributes        2 bytes
#          external file attributes        4 bytes
#          relative offset of local header 4 bytes

#          file name (variable size)
#          extra field (variable size)
#          file comment (variable size)

    }
  end
end

class ZipCentralDirectoryTest < RUNIT::TestCase

  def test_readFromStream
    File.open(TestZipFile::TEST_ZIP2.zipName, "rb") {
      |zipFile|
      cdir = ZipCentralDirectory.readFromStream(zipFile)

      assert_equals(TestZipFile::TEST_ZIP2.entryNames.size, cdir.size)
      assert(cdir.compareEnumerables(TestZipFile::TEST_ZIP2.entryNames) { 
		      |cdirEntry, testEntryName|
		      cdirEntry.name == testEntryName
		    })
      assert_equals(TestZipFile::TEST_ZIP2.comment, cdir.comment)
    }
  end

  def test_readFromInvalidStream
    File.open("ziptest.rb", "rb") {
      |zipFile|
      cdir = ZipCentralDirectory.new
      cdir.readFromStream(zipFile)
    }
    fail "ZipError expected!"
  rescue ZipError
  end
end



class ZipFileTest < RUNIT::TestCase
  include AssertEntry

  def setup
    @zipFile = ZipFile.new(TestZipFile::TEST_ZIP2.zipName)
    @testEntryNameIndex=0
  end

  def nextTestEntryName
    retVal=TestZipFile::TEST_ZIP2.entryNames[@testEntryNameIndex]
    @testEntryNameIndex+=1
    return retVal
  end
    
  def test_entries
    entries = @zipFile.entries
    assert_equals(4, entries.size)
    assert_equals(nextTestEntryName, entries[0].name)
    assert_equals(nextTestEntryName, entries[1].name)
    assert_equals(nextTestEntryName, entries[2].name)
    assert_equals(nextTestEntryName, entries[3].name)
  end

  def test_each
    @zipFile.each {
      |entry|
      assert_equals(nextTestEntryName, entry.name)
    }
    assert_equals(4, @testEntryNameIndex)
  end

  def test_foreach
    ZipFile.foreach(TestZipFile::TEST_ZIP2.zipName) {
      |entry|
      assert_equals(nextTestEntryName, entry.name)
    }
    assert_equals(4, @testEntryNameIndex)
  end

  def test_getInputStream
    @zipFile.each {
      |entry|
      assertEntry(nextTestEntryName, @zipFile.getInputStream(entry), 
		  entry.name)
    }
    assert_equals(4, @testEntryNameIndex)
  end
end



TestZipFile::createTestZips(ARGV.index("recreate") != nil)

RUNIT::CUI::TestRunner.run(RUNIT::TestCase.all_suite)

