#!/usr/bin/env ruby

$VERBOSE = true

require 'zipfilesystem'
require 'rubyunit'

module ExtraAssertions

  def assert_forwarded(anObject, method, retVal, *expectedArgs)
    callArgs = nil
    setCallArgsProc = proc { |args| callArgs = args }
    anObject.instance_eval <<-"end_eval"
      alias #{method}_org #{method}
      def #{method}(*args)
        ObjectSpace._id2ref(#{setCallArgsProc.object_id}).call(args)
        ObjectSpace._id2ref(#{retVal.object_id})
        end
    end_eval

    assert_equals(retVal, yield) # Invoke test
    assert_equals(expectedArgs, callArgs)
  ensure
    anObject.instance_eval "alias #{method} #{method}_org"
  end

end

include Zip

class ZipFsFileNonmutatingTest < RUNIT::TestCase
  def setup
    @zipFile = ZipFile.new("zipWithDirs.zip")
  end

  def teardown
    @zipFile.close if @zipFile
  end

  def test_umask
    assert_equals(File.umask, @zipFile.file.umask)
    @zipFile.file.umask(0006)
  end

  def test_exists?
    assert(! @zipFile.file.exists?("notAFile"))
    assert(@zipFile.file.exists?("file1"))
    assert(@zipFile.file.exists?("dir1"))
    assert(@zipFile.file.exists?("dir1/"))
    assert(@zipFile.file.exists?("dir1/file12"))
    assert(@zipFile.file.exist?("dir1/file12")) # notice, tests exist? alias of exists?
  end

  def test_open_read
    blockCalled = false
    @zipFile.file.open("file1", "r") {
      |f|
      blockCalled = true
      assert_equals("this is the entry 'file1' in my test archive!", 
		    f.readline.chomp)
    }
    assert(blockCalled)

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

    assert_equals(72, @zipFile.file.stat("file1").size)
    assert_equals(0, @zipFile.file.stat("dir2/dir21").size)
  end

  def test_size?
    assert_equals(nil, @zipFile.file.size?("notAFile"))
    assert_equals(72, @zipFile.file.size?("file1"))
    assert_equals(nil, @zipFile.file.size?("dir2/dir21"))

    assert_equals(72, @zipFile.file.stat("file1").size?)
    assert_equals(nil, @zipFile.file.stat("dir2/dir21").size?)
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

  include ExtraAssertions

  def test_dirname
    assert_forwarded(File, :dirname, "retVal", "a/b/c/d") { 
      @zipFile.file.dirname("a/b/c/d")
    }
  end

  def test_basename
    assert_forwarded(File, :basename, "retVal", "a/b/c/d") { 
      @zipFile.file.basename("a/b/c/d")
    }
  end

  def test_split
    assert_forwarded(File, :split, "retVal", "a/b/c/d") { 
      @zipFile.file.split("a/b/c/d")
    }
  end

  def test_join
    assert_equals("a/b/c", @zipFile.file.join("a/b", "c"))
    assert_equals("a/b/c/d", @zipFile.file.join("a/b", "c/d"))
    assert_equals("/c/d", @zipFile.file.join("", "c/d"))
    assert_equals("a/b/c/d", @zipFile.file.join("a", "b", "c", "d"))
  end

  def test_utime
    assert_exception(StandardError, "utime not supported") {
      @zipFile.file.utime(100, "file1", "dir1")
    }
  end


  def assert_always_false(operation)
    assert(! @zipFile.file.send(operation, "noSuchFile"))
    assert(! @zipFile.file.send(operation, "file1"))
    assert(! @zipFile.file.send(operation, "dir1"))
    assert(! @zipFile.file.stat("file1").send(operation))
    assert(! @zipFile.file.stat("dir1").send(operation))
  end

  def assert_true_if_entry_exists(operation)
    assert(! @zipFile.file.send(operation, "noSuchFile"))
    assert(@zipFile.file.send(operation, "file1"))
    assert(@zipFile.file.send(operation, "dir1"))
    assert(@zipFile.file.stat("file1").send(operation))
    assert(@zipFile.file.stat("dir1").send(operation))
  end

  def test_pipe?
    assert_always_false(:pipe?)
  end

  def test_blockdev?
    assert_always_false(:blockdev?)
  end

  def test_symlink?
    assert_always_false(:symlink?)
  end

  def test_socket?
    assert_always_false(:socket?)
  end

  def test_chardev?
    assert_always_false(:chardev?)
  end

  def test_truncate
    assert_exception(StandardError, "truncate not supported") {
      @zipFile.file.truncate("file1", 100)
    }
  end

  def assert_e_n_o_e_n_t(operation, args = ["NoSuchFile"])
    assert_exception(Errno::ENOENT) {
      @zipFile.file.send(operation, *args)
    }
  end

  def test_ftype
    assert_e_n_o_e_n_t(:ftype)
    assert_equals("file", @zipFile.file.ftype("file1"))
    assert_equals("directory", @zipFile.file.ftype("dir1/dir11"))
    assert_equals("directory", @zipFile.file.ftype("dir1/dir11/"))
  end

  def test_link
    assert_exception(NotImplementedError) {
      @zipFile.file.link("file1", "someOtherString")
    }
  end

  def test_directory?
    assert(! @zipFile.file.directory?("notAFile"))
    assert(! @zipFile.file.directory?("file1"))
    assert(! @zipFile.file.directory?("dir1/file11"))
    assert(@zipFile.file.directory?("dir1"))
    assert(@zipFile.file.directory?("dir1/"))
    assert(@zipFile.file.directory?("dir2/dir21"))

    assert(! @zipFile.file.stat("file1").directory?)
    assert(! @zipFile.file.stat("dir1/file11").directory?)
    assert(@zipFile.file.stat("dir1").directory?)
    assert(@zipFile.file.stat("dir1/").directory?)
    assert(@zipFile.file.stat("dir2/dir21").directory?)
  end

  def test_chown
    assert_equals(2, @zipFile.file.chown(1,2, "noSuchFile", "file1"))
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

    assert(! @zipFile.file.stat("file1").zero?)
    assert(@zipFile.file.stat("dir1").zero?)
    blockCalled = false
    ZipFile.open("4entry.zip") {
      |zf|
      blockCalled = true
      assert(zf.file.stat("empty.txt").zero?)
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

    assert_equals(Time.local(2002, "Jul", 26, 16, 38, 26),
		  @zipFile.file.stat("dir2/file21").mtime)
    assert_equals(Time.local(2002, "Jul", 26, 15, 41, 04),
		  @zipFile.file.stat("dir2/dir21").mtime)
  end

  def test_ctime
    assert_nil(@zipFile.file.ctime("file1"))
    assert_nil(@zipFile.file.stat("file1").ctime)
  end

  def test_atime
    assert_nil(@zipFile.file.atime("file1"))
    assert_nil(@zipFile.file.stat("file1").atime)
  end

  def test_readable?
    assert_true_if_entry_exists(:readable?)
  end

  def test_readable_real?
    assert_true_if_entry_exists(:readable_real?)
  end

  def test_writable?
    assert_true_if_entry_exists(:writable?)
  end

  def test_writable_real?
    assert_true_if_entry_exists(:writable_real?)
  end

  def test_executable?
    assert_true_if_entry_exists(:executable?)
  end

  def test_executable_real?
    assert_true_if_entry_exists(:executable_real?)
  end

  def test_owned?
    assert_true_if_entry_exists(:executable_real?)
  end

  def test_grpowned?
    assert_true_if_entry_exists(:executable_real?)
  end

  def test_setgid?
    assert_always_false(:setgid?)
  end

  def test_setuid?
    assert_always_false(:setgid?)
  end

  def test_sticky?
    assert_always_false(:sticky?)
  end

  def test_readlink
    assert_exception(NotImplementedError) {
      @zipFile.file.readlink("someString")
    }
  end

  def test_stat
    s = @zipFile.file.stat("file1")
    assert(s.kind_of?(File::Stat)) # It pretends
    assert_exception(Errno::ENOENT, "No such file or directory - noSuchFile") {
      @zipFile.file.stat("noSuchFile")
    }
  end

  def test_lstat
    assert(@zipFile.file.lstat("file1").file?)
  end


  def test_chmod
    assert_exception(Errno::ENOENT, "No such file or directory - noSuchFile") {
      @zipFile.file.chmod(0644, "file1", "NoSuchFile")
    }
    assert_equals(2, @zipFile.file.chmod(0644, "file1", "dir1"))
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

  def test_read
    ZipFile.open("zipWithDir.zip") {
      |zf|
      assert_equals(File.read("file1.txt"), 
		    zf.file.read("file1.txt"))
    }
  end

end

class ZipFsFileStatTest < RUNIT::TestCase

  def setup
    @zipFile = ZipFile.new("zipWithDirs.zip")
  end

  def teardown
    @zipFile.close if @zipFile
  end

  def test_blocks
    assert_equals(nil, @zipFile.file.stat("file1").blocks)
  end

  def test_ino
    assert_equals(0, @zipFile.file.stat("file1").ino)
  end

  def test_uid
    assert_equals(0, @zipFile.file.stat("file1").uid)
  end

  def test_gid
    assert_equals(0, @zipFile.file.stat("file1").gid)
  end

  def test_ftype
    assert_equals("file", @zipFile.file.stat("file1").ftype)
    assert_equals("directory", @zipFile.file.stat("dir1").ftype)
  end

  def test_mode
    fail "Implement test"
  end

  def test_dev
    assert_equals(0, @zipFile.file.stat("file1").dev)
  end

  def test_rdev
    assert_equals(0, @zipFile.file.stat("file1").rdev)
  end

  def test_rdev_major
    assert_equals(0, @zipFile.file.stat("file1").rdev_major)
  end

  def test_rdev_minor
    assert_equals(0, @zipFile.file.stat("file1").rdev_minor)
  end

  def test_nlink
    assert_equals(1, @zipFile.file.stat("file1").nlink)
  end

  def test_blksize
    assert_nil(@zipFile.file.stat("file1").blksize)
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
    do_test_delete_or_unlink(:delete)
  end

  def test_unlink
    do_test_delete_or_unlink(:unlink)
  end
  
  def test_open_write
    ZipFile.open(TEST_ZIP) {
      |zf|

      zf.file.open("test_open_write_entry", "w") {
        |f|
        blockCalled = true
        f.write "This is what I'm writing"
      }
      assert_equals("This is what I'm writing",
                    zf.file.read("test_open_write_entry"))

      # Test with existing entry
      zf.file.open("file1", "w") {
        |f|
        blockCalled = true
        f.write "This is what I'm writing too"
      }
      assert_equals("This is what I'm writing too",
                    zf.file.read("file1"))
    }
  end

  def test_rename
    ZipFile.open(TEST_ZIP) {
      |zf|
      assert_exception(Errno::ENOENT, "") { 
        zf.file.rename("NoSuchFile", "bimse")
      }
      zf.file.rename("file1", "newNameForFile1")
    }

    ZipFile.open(TEST_ZIP) {
      |zf|
      assert(! zf.file.exists?("file1"))
      assert(zf.file.exists?("newNameForFile1"))
    }
  end

  def do_test_delete_or_unlink(symbol)
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
