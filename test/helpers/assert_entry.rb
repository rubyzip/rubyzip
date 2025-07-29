# frozen_string_literal: true

module AssertEntry
  def assert_next_entry(filename, zis)
    assert_entry(filename, zis, zis.get_next_entry.name)
  end

  def assert_entry(filename, zis, entry_name)
    assert_equal(filename, entry_name)
    assert_entry_contents_for_stream(filename, zis, entry_name)
  end

  def assert_entry_contents_for_stream(filename, zis, entry_name)
    File.open(filename, 'rb') do |file|
      expected = file.read
      actual = zis.read
      if expected != actual
        if expected && actual && (expected.length > 400 || actual.length > 400)
          entry_filename = "#{entry_name}.zipEntry"
          File.open(entry_filename, 'wb') { |entryfile| entryfile << actual }
          raise("File '#{filename}' is different from '#{entry_filename}'")
        else
          assert_equal(expected, actual)
        end
      end
    end
  end

  def self.assert_contents(filename, string)
    contents = ''
    File.open(filename, 'rb') { |f| contents = f.read }
    return unless contents != string

    if contents.length > 400 || string.length > 400
      string_file = "#{filename}.other"
      File.open(string_file, 'wb') { |f| f << string }
      raise("File '#{filename}' is different from contents of string stored in '#{string_file}'")
    else
      assert_equal(contents, string)
    end
  end

  def assert_stream_contents(zis, zip_file)
    assert(!zis.nil?)
    zip_file.entry_names.each do |entry_name|
      assert_next_entry(entry_name, zis)
    end
    assert_nil(zis.get_next_entry)
  end

  def assert_test_zip_contents(zip_file)
    ::Zip::InputStream.open(zip_file.zip_name) do |zis|
      assert_stream_contents(zis, zip_file)
    end
  end

  def assert_entry_contents(zip_file, entry_name, filename = entry_name.to_s)
    zis = zip_file.get_input_stream(entry_name)
    assert_entry_contents_for_stream(filename, zis, entry_name)
  ensure
    zis.close if zis
  end
end
