require 'test_helper'

class ZipSettingsTest < MiniTest::Unit::TestCase
  # TODO Refactor out into common test module
  include CommonZipFileFixture
  TEST_OUT_NAME = "emptyOutDir"

  def setup
    super

    Dir.rmdir(TEST_OUT_NAME) if File.directory? TEST_OUT_NAME
    File.delete(TEST_OUT_NAME) if File.exist? TEST_OUT_NAME
  end

  def open_zip(&aProc)
    assert(aProc != nil)
    ::Zip::File.open(TestZipFile::TEST_ZIP4.zip_name, &aProc)
  end

  def extract_test_dir(&aProc)
    open_zip {
        |zf|
      zf.extract(TestFiles::EMPTY_TEST_DIR, TEST_OUT_NAME, &aProc)
    }
  end

  def test_true_on_exists_proc
    Zip.on_exists_proc = true
    File.open(TEST_OUT_NAME, "w") { |f| f.puts "something" }
    extract_test_dir
    assert(File.directory?(TEST_OUT_NAME))
  end

  def test_false_on_exists_proc
    Zip.on_exists_proc = false
    File.open(TEST_OUT_NAME, "w") { |f| f.puts "something" }
    assert_raises(Zip::DestinationFileExistsError) { extract_test_dir }
  end

  def test_false_continue_on_exists_proc
    Zip.continue_on_exists_proc = false

    assert_raises(::Zip::EntryExistsError) do
      ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
        zf.add(zf.entries.first.name, "test/data/file2.txt")
      end
    end
  end

  def test_true_continue_on_exists_proc
    Zip.continue_on_exists_proc = true

    replacedEntry = nil

    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      replacedEntry = zf.entries.first.name
      zf.add(replacedEntry, "test/data/file2.txt")
    end

    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_contains(zf, replacedEntry, "test/data/file2.txt")
    end
  end


  private
  def assert_contains(zf, entryName, filename = entryName)
    assert(zf.entries.detect { |e| e.name == entryName } != nil, "entry #{entryName} not in #{zf.entries.join(', ')} in zip file #{zf}")
    assert_entryContents(zf, entryName, filename) if File.exist?(filename)
  end
end
