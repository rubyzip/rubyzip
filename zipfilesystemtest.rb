#!/usr/bin/env ruby

$VERBOSE = true

require 'zip'
require 'rubyunit'

include Zip

class ZipFsFileTest < RUNIT::TestCase
  def setup
    @zipFile = ZipFile.new("zipWithDirs.zip")
    @zipFsFile = @zipFile.fileSystem.file
  end

  def teardown
    @zipFile.close if @zipFile
  end

#  def test_umask
#    fail "implement test"
#  end

#  def test_atime
#    fail "implement test"
#  end

  def test_exists?
    assert(! @zipFsFile.exists?("notAFile"))
    assert(@zipFsFile.exists?("file1"))
    assert(@zipFsFile.exists?("dir1"))
    assert(@zipFsFile.exists?("dir1/"))
    assert(@zipFsFile.exists?("dir1/file12"))
    assert(@zipFsFile.exist?("dir1/file12")) # notice, tests exist? alias of exists?
  end

  def test_open
    blockCalled = false
    @zipFsFile.open("file1", "r") {
      |f|
      blockCalled = true
      assert_equals("this is the entry 'file1' in my test archive!", 
		    f.readline.chomp)
    }
    assert(blockCalled)

    blockCalled = false
    assert_exception(StandardError) {
      @zipFsFile.open("file1", "w") { blockCalled = true }
    }
    assert(! blockCalled)

    assert_exception(Errno::ENOENT) {
      @zipFsFile.open("noSuchEntry")
    }
  end

  def test_new
    fail "implement test"
  end

  def test_symlink
    assert_exception(NotImplementedError) {
      @zipFsFile.symlink("file1", "aSymlink")
    }
  end

  def test_sticky?
    fail "implement test"
  end
  
  def test_size
    assert_exception(Errno::ENOENT) { @zipFsFile.size("notAFile") }
    assert_equals(72, @zipFsFile.size("file1"))
    assert_equals(0, @zipFsFile.size("dir2/dir21"))
  end

  def test_size?
    assert_equals(nil, @zipFsFile.size?("notAFile"))
    assert_equals(72, @zipFsFile.size?("file1"))
    assert_equals(nil, @zipFsFile.size?("dir2/dir21"))
  end


  def test_file?
    assert(@zipFsFile.file?("file1"))
    assert(@zipFsFile.file?("dir2/file21"))
    assert(! @zipFsFile.file?("dir1"))
    assert(! @zipFsFile.file?("dir1/dir11"))
  end

  def test_dirname
    assert_equals("a/b/c", @zipFsFile.dirname("a/b/c/d"))
    assert_equals(".", @zipFsFile.dirname("c"))
    assert_equals("a/b", @zipFsFile.dirname("a/b/"))
  end

  def test_basename
    assert_equals("d", @zipFsFile.basename("a/b/c/d"))
    assert_equals("c", @zipFsFile.basename("c"))
    assert_equals("", @zipFsFile.basename("a/b/"))
  end

  def test_split
    assert_equals(["a/b/c", "d"], @zipFsFile.split("a/b/c/d"))
    assert_equals(["a/b/c/d", ""], @zipFsFile.split("a/b/c/d/"))
    assert_equals([".", "a"], @zipFsFile.split("a"))
  end

  def test_join
    assert_equals("a/b/c", @zipFsFile.join("a/b", "c"))
    assert_equals("a/b/c/d", @zipFsFile.join("a/b", "c/d"))
    assert_equals("/c/d", @zipFsFile.join("", "c/d"))
    assert_equals("a/b/c/d", @zipFsFile.join("a", "b", "c", "d"))
  end

  def test_utime
    fail "implement test"
  end


  def assertAlwaysFalse(operation)
    assert(! @zipFsFile.send(operation, "noSuchFile"))
    assert(! @zipFsFile.send(operation, "file1"))
    assert(! @zipFsFile.send(operation, "dir1"))
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

  def test_writable?
    fail "implement test"
  end

  def test_truncate
    fail "implement test"
  end

  def test_rename
    fail "implement test"
  end

  def assertENOENT(operation, args = ["NoSuchFile"])
    assert_exception(Errno::ENOENT) {
      @zipFsFile.send(operation, *args)
    }
  end

  def test_ftype
    assertENOENT(:ftype)
    assert_equals("file", @zipFsFile.ftype("file1"))
    assert_equals("directory", @zipFsFile.ftype("dir1/dir11"))
    assert_equals("directory", @zipFsFile.ftype("dir1/dir11/"))
  end

  def test_grpowned?
    fail "implement test"
  end

  def test_link
    assert_exception(NotImplementedError) {
      @zipFsFile.link("file1", "someOtherString")
    }
  end

#  def test_setgid?
#    fail "implement test"
#  end

#  def test_executable_real?
#    fail "implement test"
#  end

  def test_ctime
    fail "implement test"
  end

  def test_readable_real?
    fail "implement test"
  end

  def test_unlink
    fail "implement test"
  end

  def test_lstat
    fail "implement test"
  end

  def test_owned?
    fail "implement test"
  end

  def test_directory?
    assert(! @zipFsFile.directory?("notAFile"))
    assert(! @zipFsFile.directory?("file1"))
    assert(! @zipFsFile.directory?("dir1/file11"))
    assert(@zipFsFile.directory?("dir1"))
    assert(@zipFsFile.directory?("dir1/"))
    assert(@zipFsFile.directory?("dir2/dir21"))
  end

  def test_chown
    fail "implement test"
  end

  def test_setuid?
    fail "implement test"
  end

  def test_zero?
    assert(! @zipFsFile.zero?("notAFile"))
    assert(! @zipFsFile.zero?("file1"))
    assert(@zipFsFile.zero?("dir1"))
    blockCalled = false
    ZipFile.open("4entry.zip") {
      |zf|
      blockCalled = true
      assert(zf.fileSystem.file.zero?("empty.txt"))
    }
    assert(blockCalled)
  end

  def test_executable?
    fail "implement test"
  end

  def test_expand_path
    # Cannot implement before we have a concept of current dir for zip filesystem
    fail "implement test"
  end

  def test_mtime
    assert_equals(Time.local(2002, "Jul", 26, 16, 38, 26),
		  @zipFsFile.mtime("dir2/file21"))
    assert_equals(Time.local(2002, "Jul", 26, 15, 41, 04),
		  @zipFsFile.mtime("dir2/dir21"))
    assert_exception(Errno::ENOENT) {
      @zipFsFile.mtime("noSuchEntry")
    }
  end

#  def test_readable?
#    fail "implement test"
#  end

  def test_delete
    fail "implement test"
  end

  def test_readlink
    assert_exception(NotImplementedError) {
      @zipFsFile.readlink("someString")
    }
  end

  def test_stat
    fail "implement test"
  end

#  def test_chmod
#    fail "implement test"
#  end

  def test_chardev?
    fail "implement test"
  end

#  def test_writable_real?
#    fail "implement test"
#  end

#  def test_pipe
#    fail "implement test"
#  end

  def test_foreach
    fail "implement test"
  end

  def test_popen
    fail "implement test"
  end

#  def test_select
#    fail "implement test"
#  end

  def test_readlines
    fail "implement test"
  end

end


class ZipFsDirectoryTest < RUNIT::TestCase
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

# Copyright (C) 2002 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
