#!/usr/bin/env ruby

$VERBOSE = true

require 'zipfilesystem'
require 'rubyunit'

include Zip

class ZipFsFileNonmutatingTest < RUNIT::TestCase
  def setup
    @zipFile = ZipFile.new("zipWithDirs.zip")
  end

  def teardown
    @zipFile.close if @zipFile
  end

  def test_umask
    fail "implement test"
  end

  def test_atime
    fail "implement test"
  end

  def test_exists?
    assert(! @zipFile.file.exists?("notAFile"))
    assert(@zipFile.file.exists?("file1"))
    assert(@zipFile.file.exists?("dir1"))
    assert(@zipFile.file.exists?("dir1/"))
    assert(@zipFile.file.exists?("dir1/file12"))
    assert(@zipFile.file.exist?("dir1/file12")) # notice, tests exist? alias of exists?
  end

  def test_open
    blockCalled = false
    @zipFile.file.open("file1", "r") {
      |f|
      blockCalled = true
      assert_equals("this is the entry 'file1' in my test archive!", 
		    f.readline.chomp)
    }
    assert(blockCalled)

    blockCalled = false
    assert_exception(StandardError) {
      @zipFile.file.open("file1", "w") { blockCalled = true }
    }
    assert(! blockCalled)

    assert_exception(Errno::ENOENT) {
      @zipFile.file.open("noSuchEntry")
    }

    begin
      is = @zipFile.file.open("file1")
      assert_equals("this is the entry 'file1' in my test archive!", 
		    is.readline.chomp)
    ensure
      is.close if is
    end
  end

  def test_new
    begin
      is = @zipFile.file.new("file1")
      assert_equals("this is the entry 'file1' in my test archive!", 
		    is.readline.chomp)
    ensure
      is.close if is
    end
    begin
      is = @zipFile.file.new("file1") {
	fail "should not call block"
      }
    ensure
      is.close if is
    end
  end

  def test_symlink
    assert_exception(NotImplementedError) {
      @zipFile.file.symlink("file1", "aSymlink")
    }
  end
  
  def test_size
    assert_exception(Errno::ENOENT) { @zipFile.file.size("notAFile") }
    assert_equals(72, @zipFile.file.size("file1"))
    assert_equals(0, @zipFile.file.size("dir2/dir21"))
  end

  def test_size?
    assert_equals(nil, @zipFile.file.size?("notAFile"))
    assert_equals(72, @zipFile.file.size?("file1"))
    assert_equals(nil, @zipFile.file.size?("dir2/dir21"))
  end


  def test_file?
    assert(@zipFile.file.file?("file1"))
    assert(@zipFile.file.file?("dir2/file21"))
    assert(! @zipFile.file.file?("dir1"))
    assert(! @zipFile.file.file?("dir1/dir11"))

    assert(@zipFile.file.stat("file1").file?)
    assert(@zipFile.file.stat("dir2/file21").file?)
    assert(! @zipFile.file.stat("dir1").file?)
    assert(! @zipFile.file.stat("dir1/dir11").file?)
  end

  def test_dirname
    assert_equals("a/b/c", @zipFile.file.dirname("a/b/c/d"))
    assert_equals(".", @zipFile.file.dirname("c"))
    assert_equals("a/b", @zipFile.file.dirname("a/b/"))
  end

  def test_basename
    assert_equals("d", @zipFile.file.basename("a/b/c/d"))
    assert_equals("c", @zipFile.file.basename("c"))
    assert_equals("", @zipFile.file.basename("a/b/"))
  end

  def test_split
    assert_equals(["a/b/c", "d"], @zipFile.file.split("a/b/c/d"))
    assert_equals(["a/b/c/d", ""], @zipFile.file.split("a/b/c/d/"))
    assert_equals([".", "a"], @zipFile.file.split("a"))
  end

  def test_join
    assert_equals("a/b/c", @zipFile.file.join("a/b", "c"))
    assert_equals("a/b/c/d", @zipFile.file.join("a/b", "c/d"))
    assert_equals("/c/d", @zipFile.file.join("", "c/d"))
    assert_equals("a/b/c/d", @zipFile.file.join("a", "b", "c", "d"))
  end

  def test_utime
    fail "implement test"
  end


  def assertAlwaysFalse(operation)
    assert(! @zipFile.file.send(operation, "noSuchFile"))
    assert(! @zipFile.file.send(operation, "file1"))
    assert(! @zipFile.file.send(operation, "dir1"))
    assert(! @zipFile.file.stat("noSuchFile").send(operation))
    assert(! @zipFile.file.stat("file1").send(operation))
    assert(! @zipFile.file.stat("dir1").send(operation))
  end

  def assertTrueIfEntryExists(operation)
    assert(! @zipFile.file.send(operation, "noSuchFile"))
    assert(@zipFile.file.send(operation, "file1"))
    assert(@zipFile.file.send(operation, "dir1"))
    assert(! @zipFile.file.stat("noSuchFile").send(operation))
    assert(@zipFile.file.stat("file1").send(operation))
    assert(@zipFile.file.stat("dir1").send(operation))
  end

  def test_pipe?
    assertAlwaysFalse(:pipe?)
  end

  def test_blockdev?
    assertAlwaysFalse(:blockdev?)
  end

  def test_symlink?
    assertAlwaysFalse(:symlink?)
  end

  def test_socket?
    assertAlwaysFalse(:socket?)
  end

  def test_chardev?
    assertAlwaysFalse(:chardev?)
  end

  def test_truncate
    fail "implement test"
  end

  def test_rename
    fail "implement test"
  end

  def assertENOENT(operation, args = ["NoSuchFile"])
    assert_exception(Errno::ENOENT) {
      @zipFile.file.send(operation, *args)
    }
  end

  def test_ftype
    assertENOENT(:ftype)
    assert_equals("file", @zipFile.file.ftype("file1"))
    assert_equals("directory", @zipFile.file.ftype("dir1/dir11"))
    assert_equals("directory", @zipFile.file.ftype("dir1/dir11/"))
  end

  def test_link
    assert_exception(NotImplementedError) {
      @zipFile.file.link("file1", "someOtherString")
    }
  end

  def test_ctime
    fail "implement test"
  end

  def test_lstat
    fail "implement test"
  end


  def test_directory?
    assert(! @zipFile.file.directory?("notAFile"))
    assert(! @zipFile.file.directory?("file1"))
    assert(! @zipFile.file.directory?("dir1/file11"))
    assert(@zipFile.file.directory?("dir1"))
    assert(@zipFile.file.directory?("dir1/"))
    assert(@zipFile.file.directory?("dir2/dir21"))

    assert(! @zipFile.file.stat("notAFile").directory?)
    assert(! @zipFile.file.stat("file1").directory?)
    assert(! @zipFile.file.stat("dir1/file11").directory?)
    assert(@zipFile.file.stat("dir1").directory?)
    assert(@zipFile.file.stat("dir1/").directory?)
    assert(@zipFile.file.stat("dir2/dir21").directory?)
  end

  def test_chown
    fail "implement test"
  end

  def test_zero?
    assert(! @zipFile.file.zero?("notAFile"))
    assert(! @zipFile.file.zero?("file1"))
    assert(@zipFile.file.zero?("dir1"))
    blockCalled = false
    ZipFile.open("4entry.zip") {
      |zf|
      blockCalled = true
      assert(zf.file.zero?("empty.txt"))
    }
    assert(blockCalled)
  end

  def test_expand_path
    # Cannot implement before we have a concept of current dir for zip filesystem
    fail "implement test"
  end

  def test_mtime
    assert_equals(Time.local(2002, "Jul", 26, 16, 38, 26),
		  @zipFile.file.mtime("dir2/file21"))
    assert_equals(Time.local(2002, "Jul", 26, 15, 41, 04),
		  @zipFile.file.mtime("dir2/dir21"))
    assert_exception(Errno::ENOENT) {
      @zipFile.file.mtime("noSuchEntry")
    }
  end


  def test_readable?
    assertTrueIfEntryExists(:readable?)
  end

  def test_readable_real?
    assertTrueIfEntryExists(:readable_real?)
  end

  def test_writable?
    assertTrueIfEntryExists(:writable?)
  end

  def test_writable_real?
    assertTrueIfEntryExists(:writable_real?)
  end

  def test_executable?
    assertTrueIfEntryExists(:executable?)
  end

  def test_executable_real?
    assertTrueIfEntryExists(:executable_real?)
  end

  def test_owned?
    assertTrueIfEntryExists(:executable_real?)
  end

  def test_grpowned?
    assertTrueIfEntryExists(:executable_real?)
  end

  def test_setgid?
    assertAlwaysFalse(:setgid?)
  end

  def test_setuid?
    assertAlwaysFalse(:setgid?)
  end

  def test_sticky?
    assertAlwaysFalse(:sticky?)
  end

  def test_readlink
    assert_exception(NotImplementedError) {
      @zipFile.file.readlink("someString")
    }
  end

  def test_stat
    fail "implement test"
  end

  def test_chmod
    fail "implement test"
  end

  def test_pipe
    assert_exception(NotImplementedError) {
      @zipFile.file.pipe
    }
  end

  def test_foreach
    ZipFile.open("zipWithDir.zip") {
      |zf|
      ref = []
      File.foreach("file1.txt") { |e| ref << e }
      
      index = 0
      zf.file.foreach("file1.txt") { 
	|l|
	assert_equals(ref[index], l)
	index = index.next
      }
      assert_equals(ref.size, index)
    }
    
    ZipFile.open("zipWithDir.zip") {
      |zf|
      ref = []
      File.foreach("file1.txt", " ") { |e| ref << e }
      
      index = 0
      zf.file.foreach("file1.txt", " ") { 
	|l|
	assert_equals(ref[index], l)
	index = index.next
      }
      assert_equals(ref.size, index)
    }
  end

  def test_popen
    assert_equals(File.popen("ls")          { |f| f.read }, 
		  @zipFile.file.popen("ls") { |f| f.read })
  end

  def test_select
    fail "implement test"
  end

  def test_readlines
    ZipFile.open("zipWithDir.zip") {
      |zf|
      assert_equals(File.readlines("file1.txt"), 
		    zf.file.readlines("file1.txt"))
    }
  end

end

class ZipFsFileStatTest #< RUNIT::TestCase

  def test_blocks
    fail "Implement test"
  end

  def test_ino
    fail "Implement test"
  end

  def test_ftype
    fail "Implement test"
  end

  def test_rdev
    fail "Implement test"
  end

  def test_to_s
    fail "Implement test"
  end

  def test_mode
    fail "Implement test"
  end

  def test_rdev_major
    fail "Implement test"
  end

  def test_atime
    fail "Implement test"
  end

  def test_size?
    fail "Implement test"
  end

  def test_nlink
    fail "Implement test"
  end

  def test_mtime
    fail "Implement test"
  end

  def test_rdev_minor
    fail "Implement test"
  end

  def test_uid
    fail "Implement test"
  end

  def test_blksize
    fail "Implement test"
  end

  def test_ctime
    fail "Implement test"
  end

  def test_zero?
    fail "Implement test"
  end

  def test_size
    fail "Implement test"
  end

  def test_dev
    fail "Implement test"
  end

  def test_gid
    fail "Implement test"
  end

end

class ZipFsFileMutatingTest < RUNIT::TestCase
  TEST_ZIP = "zipWithDirs_copy.zip"
  def setup
    File.copy("zipWithDirs.zip", TEST_ZIP)
  end

  def teardown
  end
 
  def test_delete
    doTest_deleteOrUnlink(:delete)
  end

  def test_unlink
    doTest_deleteOrUnlink(:unlink)
  end

  def doTest_deleteOrUnlink(symbol)
    ZipFile.open(TEST_ZIP) {
      |zf|
      assert(zf.file.exists?("dir2/dir21/dir221/file2221"))
      zf.file.send(symbol, "dir2/dir21/dir221/file2221")
      assert(! zf.file.exists?("dir2/dir21/dir221/file2221"))

      assert(zf.file.exists?("dir1/file11"))
      assert(zf.file.exists?("dir1/file12"))
      zf.file.send(symbol, "dir1/file11", "dir1/file12")
      assert(! zf.file.exists?("dir1/file11"))
      assert(! zf.file.exists?("dir1/file12"))

      assert_exception(Errno::ENOENT) { zf.file.send(symbol, "noSuchFile") }
      assert_exception(Errno::EISDIR) { zf.file.send(symbol, "dir1/dir11") }
      assert_exception(Errno::EISDIR) { zf.file.send(symbol, "dir1/dir11/") }
    }

    ZipFile.open(TEST_ZIP) {
      |zf|
      assert(! zf.file.exists?("dir2/dir21/dir221/file2221"))
      assert(! zf.file.exists?("dir1/file11"))
      assert(! zf.file.exists?("dir1/file12"))

      assert(zf.file.exists?("dir1/dir11"))
      assert(zf.file.exists?("dir1/dir11/"))
    }
  end

end

class ZipFsDirectoryTest #< RUNIT::TestCase
  def test_rmdir
    fail "implement test"
  end

  def test_open
    fail "implement test"
  end

  def test_getwd
    fail "implement test"
  end

  def test_mkdir
    fail "implement test"
  end

  def test_chdir
    fail "implement test"
  end

  def test_indexOperator # ie []
    fail "implement test"
  end

  def test_unlink
    fail "implement test"
  end

  def test_entries
    fail "implement test"
  end

  def test_foreach
    fail "implement test"
  end

  def test_chroot
    fail "implement test"
  end

  def test_glob
    fail "implement test"
  end

  def test_delete
    fail "implement test"
  end

  def test_pwd
    fail "implement test"
  end

end

END {
  if __FILE__ == $0
    Dir.chdir "test"
  end
}

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
