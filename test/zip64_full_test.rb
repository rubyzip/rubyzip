# frozen_string_literal: true

require_relative 'test_helper'

# Test zip64 support for real by actually exceeding the 32-bit
# size/offset limits. This test does not, of course, run with the
# normal unit tests! ;)
class Zip64FullTest < Minitest::Test
  HUGE_ZIP = 'huge.zip'

  def teardown
    ::Zip.reset!
    ::FileUtils.rm_f HUGE_ZIP
  end

  def test_large_zip_file
    skip unless ENV['FULL_ZIP64_TEST'] && !Zip::RUNNING_ON_WINDOWS

    first_text = 'starting out small'
    last_text = 'this tests files starting after 4GB in the archive'
    comment_text = 'this is a file comment in a zip64 archive'

    ::Zip::File.open(HUGE_ZIP, create: true) do |zf|
      zf.comment = comment_text

      zf.get_output_stream('first_file.txt') do |io|
        io.write(first_text)
      end

      # Write just over 4GB (stored, so the zip file exceeds 4GB).
      buf = 'blah' * 16_384
      zf.get_output_stream(
        'huge_file', compression_method: ::Zip::COMPRESSION_METHOD_STORE
      ) do |io|
        65_537.times { io.write(buf) }
      end

      zf.get_output_stream('last_file.txt') do |io|
        io.write(last_text)
      end
    end

    ::Zip::File.open(HUGE_ZIP) do |zf|
      assert_equal(
        %w[first_file.txt huge_file last_file.txt], zf.entries.map(&:name)
      )
      assert_equal(first_text, zf.read('first_file.txt'))
      assert_equal(last_text, zf.read('last_file.txt'))
      assert_equal(comment_text, zf.comment)
    end

    # NOTE: if this fails, be sure you have UnZip version 6.0 or newer
    # as this is the first version to support zip64 extensions
    # but some OSes (*cough* OSX) still bundle a 5.xx release
    assert(
      system("unzip -tqq #{HUGE_ZIP}"),
      'third-party zip validation failed'
    )
  end
end
