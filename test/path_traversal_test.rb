class PathTraversalTest < MiniTest::Test
  TEST_FILE_ROOT = File.absolute_path('test/data/jwilk-path-traversal-samples')

  def setup
    FileUtils.rm_f '/tmp/moo' # with apologies to anyone using this file
  end

  def extract_path_traversal_zip(name)
    Zip::File.open(File.join(TEST_FILE_ROOT, name)) do |zip_file|
      zip_file.each do |entry|
        entry.extract
      end
    end
  end

  def in_tmpdir
    Dir.mktmpdir do |tmp|
      test_path = File.join(tmp, 'test')
      Dir.mkdir test_path
      Dir.chdir(test_path) do
        yield
      end
    end
  end

  def test_leading_slash
    in_tmpdir do
      extract_path_traversal_zip 'absolute1.zip'
      assert !File.exist?('/tmp/moo')
    end
  end

  def test_multiple_leading_slashes
    in_tmpdir do
      extract_path_traversal_zip 'absolute2.zip'
      assert !File.exist?('/tmp/moo')
    end
  end

  def test_leading_dot_dot
    in_tmpdir do
      extract_path_traversal_zip 'relative0.zip'
      assert !File.exist?('../moo')
    end
  end

  def test_non_leading_dot_dot
    in_tmpdir do
      extract_path_traversal_zip 'relative2.zip'
      assert !File.exist?('../moo')
    end
  end

  def test_file_symlink
    in_tmpdir do
      extract_path_traversal_zip 'symlink.zip'
      assert File.exist?('moo')
      assert !File.exist?('/tmp/moo')
    end
  end

  def test_directory_symlink
    in_tmpdir do
      extract_path_traversal_zip 'dirsymlink.zip'
      assert !File.exist?('/tmp/moo')
    end
  end

  def test_two_directory_symlinks_a
    in_tmpdir do
      # Can't create par/moo because the symlink par is skipped.
      assert_raises Errno::ENOENT do
        extract_path_traversal_zip 'dirsymlink2a.zip'
      end
      assert File.exist?('cur')
      assert_equal '.', File.readlink('cur')
    end
  end

  def test_two_directory_symlinks_b
    in_tmpdir do
      extract_path_traversal_zip 'dirsymlink2b.zip'
      assert File.exist?('cur')
      assert_equal '.', File.readlink('cur')
      assert !File.exist?('../moo')
    end
  end
end
