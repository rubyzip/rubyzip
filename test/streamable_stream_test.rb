require 'test_helper'

class FakeEntry
  def name
    'something'
  end

  def zipfile
    'data/important_stuff.zip'
  end
end

class StreamableStreamTest < MiniTest::Test
  def test_use_system_temp_dir_true
    entry = FakeEntry.new
    stream = ::Zip::StreamableStream.new(entry, true)
    stream.get_output_stream do |temp_file|
      assert(temp_file.path.start_with?(Dir.tmpdir))
    end
  end

  def test_use_system_temp_dir_false
    entry = FakeEntry.new
    FileUtils.mkdir_p(File.dirname(entry.zipfile))
    stream = ::Zip::StreamableStream.new(entry, false)
    stream.get_output_stream do |temp_file|
      assert(temp_file.path.start_with?('data/'))
    end
    FileUtils.rm_r(File.dirname(entry.zipfile))
  end
end
