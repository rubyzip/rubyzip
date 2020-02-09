require 'test_helper'

class PathTraversalTest < MiniTest::Test
  TEST_FILE_ROOT = File.absolute_path('test/data/path_traversal')

  def setup
    # With apologies to anyone using these files... but they are the files in
    # the sample zips, so we don't have much choice here.
    FileUtils.rm_f '/tmp/moo'
    FileUtils.rm_f '/tmp/file.txt'
  end

  def extract_paths(zip_path, entries)
    ::Zip::File.open(::File.join(TEST_FILE_ROOT, zip_path)) do |zip|
      entries.each do |entry, test|
        if test == :error
          assert_raises(Errno::ENOENT) do
            zip.find_entry(entry).extract
          end
        else
          assert_output('', test) do
            zip.find_entry(entry).extract
          end
        end
      end
    end
  end

  def in_tmpdir
    Dir.mktmpdir do |tmp|
      test_path = File.join(tmp, 'test')
      Dir.mkdir test_path
      Dir.chdir test_path do
        yield test_path
      end
    end
  end

  def test_leading_slash
    entries = { '/tmp/moo' => /WARNING: skipped \'\/tmp\/moo\'/ }
    in_tmpdir do
      extract_paths(['jwilk', 'absolute1.zip'], entries)
      refute File.exist?('/tmp/moo')
    end
  end

  def test_multiple_leading_slashes
    entries = { '//tmp/moo' => /WARNING: skipped \'\/\/tmp\/moo\'/ }
    in_tmpdir do
      extract_paths(['jwilk', 'absolute2.zip'], entries)
      refute File.exist?('/tmp/moo')
    end
  end

  def test_leading_dot_dot
    entries = { '../moo' => /WARNING: skipped \'\.\.\/moo\'/ }
    in_tmpdir do
      extract_paths(['jwilk', 'relative0.zip'], entries)
      refute File.exist?('../moo')
    end
  end

  def test_non_leading_dot_dot_with_existing_folder
    entries = {
      'tmp/'          => '',
      'tmp/../../moo' => /WARNING: skipped \'tmp\/\.\.\/\.\.\/moo\'/
    }
    in_tmpdir do
      extract_paths('relative1.zip', entries)
      assert Dir.exist?('tmp')
      refute File.exist?('../moo')
    end
  end

  def test_non_leading_dot_dot_without_existing_folder
    entries = { 'tmp/../../moo' => /WARNING: skipped \'tmp\/\.\.\/\.\.\/moo\'/ }
    in_tmpdir do
      extract_paths(['jwilk', 'relative2.zip'], entries)
      refute File.exist?('../moo')
    end
  end

  def test_file_symlink
    entries = { 'moo' => '' }
    in_tmpdir do
      extract_paths(['jwilk', 'symlink.zip'], entries)
      assert File.exist?('moo')
      refute File.exist?('/tmp/moo')
    end
  end

  def test_directory_symlink
    # Can't create tmp/moo, because the tmp symlink is skipped.
    entries = {
      'tmp'     => /WARNING: skipped symlink \'tmp\'/,
      'tmp/moo' => :error
    }
    in_tmpdir do
      extract_paths(['jwilk', 'dirsymlink.zip'], entries)
      refute File.exist?('/tmp/moo')
    end
  end

  def test_two_directory_symlinks_a
    # Can't create par/moo because the symlinks are skipped.
    entries = {
      'cur'     => /WARNING: skipped symlink \'cur\'/,
      'par'     => /WARNING: skipped symlink \'par\'/,
      'par/moo' => :error
    }
    in_tmpdir do
      extract_paths(['jwilk', 'dirsymlink2a.zip'], entries)
      refute File.exist?('cur')
      refute File.exist?('par')
      refute File.exist?('par/moo')
    end
  end

  def test_two_directory_symlinks_b
    # Can't create par/moo, because the symlinks are skipped.
    entries = {
      'cur'     => /WARNING: skipped symlink \'cur\'/,
      'cur/par' => /WARNING: skipped symlink \'cur\/par\'/,
      'par/moo' => :error
    }
    in_tmpdir do
      extract_paths(['jwilk', 'dirsymlink2b.zip'], entries)
      refute File.exist?('cur')
      refute File.exist?('../moo')
    end
  end

  def test_entry_name_with_absolute_path_does_not_extract
    entries = {
      '/tmp/'         => /WARNING: skipped \'\/tmp\/\'/,
      '/tmp/file.txt' => /WARNING: skipped \'\/tmp\/file.txt\'/
    }
    in_tmpdir do
      extract_paths(['tuzovakaoff', 'absolutepath.zip'], entries)
      refute File.exist?('/tmp/file.txt')
    end
  end

  def test_entry_name_with_absolute_path_extract_when_given_different_path
    in_tmpdir do |test_path|
      zip_path = File.join(TEST_FILE_ROOT, 'tuzovakaoff', 'absolutepath.zip')
      Zip::File.open(zip_path) do |zip_file|
        zip_file.each do |entry|
          entry.extract(File.join(test_path, entry.name))
        end
      end
      refute File.exist?('/tmp/file.txt')
    end
  end

  def test_entry_name_with_relative_symlink
    # Doesn't create the symlink path, so can't create path/file.txt.
    entries = {
      'path'          => /WARNING: skipped symlink \'path\'/,
      'path/file.txt' => :error
    }
    in_tmpdir do
      extract_paths(['tuzovakaoff', 'symlink.zip'], entries)
      refute File.exist?('/tmp/file.txt')
    end
  end

  def test_entry_name_with_tilde
    in_tmpdir do
      extract_paths('tilde.zip', '~tilde~' => '')
      assert File.exist?('~tilde~')
    end
  end
end
