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

  def test_pipe?
    assert(! @zipFsFile.pipe?("notAFile"))
    assert(! @zipFsFile.pipe?("file1"))
  end

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

#  def test_symlink
#    fail "implement test"
#  end

#  def test_sticky?
#    fail "implement test"
#  end

  def test_size
    assert_exception(Errno::ENOENT) { @zipFsFile.size("notAFile") }
    assert_equals(72, @zipFsFile.size("file1"))
    assert_equals(0, @zipFsFile.size("dir2/dir21"))
  end

  def test_file?
    fail "implement test"
  end

  def test_dirname
    fail "implement test"
  end

  def test_utime
    fail "implement test"
  end

  def test_blockdev?
    fail "implement test"
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

  def test_ftype
    fail "implement test"
  end

  def test_grpowned?
    fail "implement test"
  end

  def test_join
    fail "implement test"
  end

  def test_link
    fail "implement test"
  end

#  def test_setgid?
#    fail "implement test"
#  end

#  def test_executable_real?
#    fail "implement test"
#  end

  def test_basename
    fail "implement test"
  end

  def test_ctime
    fail "implement test"
  end

  def test_socket?
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
    fail "implement test"
  end

  def test_chown
    fail "implement test"
  end

  def test_setuid?
    fail "implement test"
  end

  def test_zero?
    fail "implement test"
  end

  def test_executable?
    fail "implement test"
  end

  def test_expand_path
    fail "implement test"
  end

  def test_mtime
    fail "implement test"
  end

  def test_symlink?
    fail "implement test"
  end

  def test_readable?
    fail "implement test"
  end

  def test_split
    fail "implement test"
  end

  def test_delete
    fail "implement test"
  end

  def test_readlink
    fail "implement test"
  end

  def test_stat
    fail "implement test"
  end

  def test_size?
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
