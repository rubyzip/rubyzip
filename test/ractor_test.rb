# frozen_string_literal: true

require_relative 'test_helper'
require 'zip/filesystem'

class RactorTest < Minitest::Test
  DATA_DIR = 'test/data'
  OUT_DIR = 'test/data/generated'

  # An extra field registered after rubyzip has loaded, as a third party would.
  class RactorField < ::Zip::ExtraField::Generic
    HEADER_ID = +'Rz'
    register_map

    attr_reader :data

    def initialize(binstr = nil)
      super()
      @data = nil
      binstr && merge(binstr)
    end

    def merge(binstr)
      _, @data = initial_parse(binstr)
    end
  end

  def setup
    skip 'Ractor is not available on this Ruby.' unless defined?(Ractor)
    # Before 3.4, a Ractor cannot call `require`, which rubyzip uses to load
    # openssl, and the standard library has more parts that it cannot use.
    skip 'Ractors need Ruby 3.4 or later.' if RUBY_VERSION < '3.4'
  end

  def test_file_read
    path = "#{DATA_DIR}/osx-archive.zip"
    expected = Zip::File.open(path) do |zip|
      zip.entries.map do |entry|
        [entry.name, entry.directory?, entry.time.to_i, entry.get_input_stream.read]
      end
    end

    result = in_ractor(path) do |zip_path|
      Zip::File.open(zip_path) do |zip|
        zip.entries.map do |entry|
          [entry.name, entry.directory?, entry.time.to_i, entry.get_input_stream.read]
        end
      end
    end

    assert_equal(expected, result)
  end

  def test_file_read_extra_fields
    result = in_ractor(DATA_DIR) do |dir|
      %w[ntfs.zip zip64-sample.zip].map do |name|
        Zip::File.open("#{dir}/#{name}") { |zip| zip.entries.flat_map { |e| e.extra.keys } }
      end
    end

    assert_includes(result[0], :ntfs)
    assert_includes(result[1], :zip64)
    assert_includes(result[1], :universaltime)
    assert_includes(result[1], :iunix)
  end

  def test_registered_extra_field
    result = in_ractor do
      extra = Zip::ExtraField.new("Rz\x03\x00abc")
      [extra[:ractorfield].class, extra[:ractorfield].data, Zip::ExtraField::ID_MAP['Rz']]
    end

    assert_equal([RactorField, 'abc', RactorField], result)
  end

  def test_input_stream_read
    result = in_ractor("#{DATA_DIR}/zipWithStoredCompression.zip") do |path|
      contents = {}
      Zip::InputStream.open(path) do |zis|
        while (entry = zis.get_next_entry)
          contents[entry.name] = zis.read
        end
      end
      contents
    end

    assert_equal(::File.read("#{DATA_DIR}/file1.txt"), result['file1.txt'])
    assert_equal(::File.read("#{DATA_DIR}/file2.txt"), result['file2.txt'])
  end

  def test_output_stream_write
    buffer = in_ractor do
      Zip::OutputStream.write_buffer(StringIO.new) do |zos|
        zos.put_next_entry('deflated.txt')
        zos.write 'Deflated in a Ractor.'
        zos.put_next_entry('stored.txt', nil, nil, Zip::Entry::STORED)
        zos.write 'Stored in a Ractor.'
      end.string
    end

    Zip::InputStream.open(StringIO.new(buffer)) do |zis|
      assert_equal('deflated.txt', zis.get_next_entry.name)
      assert_equal('Deflated in a Ractor.', zis.read)
      assert_equal('stored.txt', zis.get_next_entry.name)
      assert_equal('Stored in a Ractor.', zis.read)
    end
  end

  def test_file_update
    path = "#{OUT_DIR}/ractor_update.zip"
    FileUtils.cp("#{DATA_DIR}/rubycode.zip", path)

    names = in_ractor(path, "#{DATA_DIR}/file1.txt") do |zip_path, file_path|
      Zip::File.open(zip_path) do |zip|
        zip.add('file1.txt', file_path)
        zip.rename(zip.entries.first, 'renamed.rb')
        zip.comment = 'Updated in a Ractor.'
      end

      Zip::File.open(zip_path) { |zip| zip.entries.map(&:name) }
    end

    assert_includes(names, 'file1.txt')
    assert_includes(names, 'renamed.rb')
    Zip::File.open(path) do |zip|
      assert_equal('Updated in a Ractor.', zip.comment)
      assert_equal(::File.read("#{DATA_DIR}/file1.txt"), zip.read('file1.txt'))
    end
  ensure
    FileUtils.rm_f(path)
  end

  def test_file_get_output_stream
    path = "#{OUT_DIR}/ractor_create.zip"
    # Zip::File keeps new entries in a Tempfile, which a Ractor cannot use
    # before Ruby 4.0.
    skip 'Tempfile needs Ruby 4.0 or later in a Ractor.' if RUBY_VERSION < '4.0'

    FileUtils.rm_f(path)

    in_ractor(path) do |zip_path|
      Zip::File.open(zip_path, create: true) do |zip|
        zip.get_output_stream('dir/new.txt') { |os| os.write 'New in a Ractor.' }
      end
    end

    Zip::File.open(path) do |zip|
      assert_equal('New in a Ractor.', zip.read('dir/new.txt'))
    end
  ensure
    FileUtils.rm_f(path)
  end

  def test_filesystem
    path = "#{DATA_DIR}/zipWithDirs.zip"
    file1 = Zip::File.open(path) { |zip| zip.read('file1') }

    result = in_ractor(path) do |zip_path|
      Zip::File.open(zip_path) do |zip|
        [zip.dir.entries('/').sort, zip.file.stat('file1').file?, zip.file.read('file1')]
      end
    end

    assert_equal([%w[dir1 dir2 file1], true, file1], result)
  end

  def test_traditional_encryption
    result = in_ractor do
      buffer = Zip::OutputStream.write_buffer(
        StringIO.new, encrypter: Zip::TraditionalEncrypter.new('password')
      ) do |zos|
        zos.put_next_entry('secret.txt')
        zos.write 'Encrypted in a Ractor.'
      end

      Zip::InputStream.open(buffer, decrypter: Zip::TraditionalDecrypter.new('password')) do |zis|
        zis.get_next_entry
        zis.read
      end
    end

    assert_equal('Encrypted in a Ractor.', result)
  end

  def test_aes_encryption
    result = in_ractor do
      strength = Zip::AESEncryption::STRENGTH_256_BIT
      buffer = Zip::OutputStream.write_buffer(
        StringIO.new, encrypter: Zip::AESEncrypter.new('password', strength)
      ) do |zos|
        zos.put_next_entry('secret.txt')
        zos.write 'Encrypted in a Ractor.'
      end

      Zip::InputStream.open(buffer, decrypter: Zip::AESDecrypter.new('password', strength)) do |zis|
        zis.get_next_entry
        zis.read
      end
    end

    assert_equal('Encrypted in a Ractor.', result)
  end

  private

  # Run the block in a new Ractor, and return its result. Raise the error
  # that stopped the Ractor, if any, rather than Ractor::RemoteError.
  def in_ractor(...)
    experimental = Warning[:experimental]
    Warning[:experimental] = false
    ractor = Ractor.new(...)
    ractor.respond_to?(:value) ? ractor.value : ractor.take
  rescue Ractor::RemoteError => e
    raise e.cause, cause: nil
  ensure
    Warning[:experimental] = experimental
  end
end
