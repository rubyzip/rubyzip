# frozen_string_literal: true

require_relative '../test_helper'

require 'zip/ioextras'

class AbstractInputStreamTest < Minitest::Test
  # AbstractInputStream subclass that provides a read method

  TEST_LINES = [
    "Hello world#{$INPUT_RECORD_SEPARATOR}",
    "this is the second line#{$INPUT_RECORD_SEPARATOR}",
    'this is the last line'
  ].freeze
  TEST_STRING = TEST_LINES.join

  LONG_LINES = [
    "#{'x' * 48}\r\n",
    "#{'y' * 49}\r\n",
    'rest'
  ].freeze

  # 'é' is two bytes when encoded as UTF-8; '👍' is four.
  UTF8_STRING = "ééé👍abc\nsecond line\n"

  class TestAbstractInputStream
    include ::Zip::IOExtras::AbstractInputStream

    def initialize(string, **opts)
      super(**opts)
      @contents = string
      @read_ptr = 0
    end

    def produce_input(maxlen = 100)
      maxlen ||= @contents.length
      ret_val = @contents[@read_ptr, maxlen]
      @read_ptr += ret_val ? ret_val.length : 0
      ret_val
    end

    def input_finished?
      @contents[@read_ptr].nil?
    end
  end

  # Hands out its chunks one at a time. An empty final chunk mimics
  # Inflater#read when the deflate end-of-stream marker arrives on its own.
  class ChunkedInputStream
    include Zip::IOExtras::AbstractInputStream

    def initialize(chunks, **opts)
      super(**opts)
      @chunks = chunks.map(&:b)
    end

    def produce_input(_maxlen = nil)
      @chunks.shift
    end

    def input_finished?
      @chunks.empty?
    end
  end

  def read_without_arguments
    io = TestAbstractInputStream.new(TEST_STRING)

    result = io.read
    assert_equal(TEST_STRING, result)
    assert_equal(TEST_STRING.length, io.pos)
    assert_equal(Encoding::ASCII_8BIT, result.encoding)
    assert_predicate(io, :eof?)
    assert_equal('', io.read)
    assert_equal(TEST_STRING.length, io.pos)
  end

  def test_read_with_maxlen
    io = TestAbstractInputStream.new(TEST_STRING)

    result = io.read(5)
    assert_equal(TEST_STRING[0, 5], result)
    assert_equal(5, io.pos)
    assert_equal(Encoding::ASCII_8BIT, result.encoding)

    result = io.read(0)
    assert_equal('', result)
    assert_equal(5, io.pos)

    result = io.read(6)
    assert_equal(TEST_STRING[5, 6], result)
    assert_equal(11, io.pos)
    assert_equal(Encoding::ASCII_8BIT, result.encoding)

    result = io.read(100)
    assert_equal(TEST_STRING[11, 100], result)
    assert_equal(TEST_STRING.length, io.pos)
    assert_equal(Encoding::ASCII_8BIT, result.encoding)

    assert_predicate(io, :eof?)
    assert_nil(io.read(1))
    assert_equal('', io.read(0))
    assert_equal(TEST_STRING.length, io.pos)
  end

  def test_read_with_outstring
    io = TestAbstractInputStream.new(TEST_STRING)

    out_string = +''
    result = io.read(5, out_string)
    assert_equal(TEST_STRING[0, 5], result)
    assert_equal(TEST_STRING[0, 5], out_string)
    assert_same(result, out_string)
    assert_equal(5, io.pos)
    assert_equal(Encoding::UTF_8, result.encoding)

    result = io.read(6, out_string)
    assert_equal(TEST_STRING[5, 6], result)
    assert_equal(TEST_STRING[5, 6], out_string)
    assert_same(result, out_string)
    assert_equal(11, io.pos)
    assert_equal(Encoding::UTF_8, result.encoding)

    out_string = +''.b
    result = io.read(6, out_string)
    assert_equal(TEST_STRING[11, 6], result)
    assert_equal(TEST_STRING[11, 6], out_string)
    assert_same(result, out_string)
    assert_equal(17, io.pos)
    assert_equal(Encoding::ASCII_8BIT, result.encoding)

    result = io.read(nil, out_string)
    assert_equal(TEST_STRING[17..], result)
    assert_equal(TEST_STRING[17..], out_string)
    assert_same(result, out_string)
    assert_equal(TEST_STRING.length, io.pos)
    assert_equal(Encoding::ASCII_8BIT, result.encoding)
  end

  def test_read_with_utf8_encoding
    io = TestAbstractInputStream.new(TEST_STRING, internal_encoding: Encoding::UTF_8)
    assert_equal(Encoding::UTF_8, io.read&.encoding)
  end

  def test_read_with_encoding_and_outstring
    io = TestAbstractInputStream.new(TEST_STRING, internal_encoding: Encoding::UTF_8)
    out_string = +''.b
    assert_equal(io.read(5, out_string).encoding, Encoding::BINARY)
  end

  def test_gets
    io = line_tests

    # gets should return nil if we're already at the end of the stream.
    assert_nil(io.gets)
    assert_equal(3, io.lineno)
  end

  def test_gets_with_nil_separator
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal(TEST_STRING, io.gets(nil))
    assert_equal(1, io.lineno)
    assert_equal(TEST_STRING.length, io.pos)
    assert_predicate(io, :eof?)
    assert_nil(io.gets(nil))
    assert_equal(1, io.lineno)
  end

  def test_gets_with_empty_string_separator
    paragraphs = TEST_LINES.join($INPUT_RECORD_SEPARATOR)
    io = TestAbstractInputStream.new(paragraphs)

    assert_equal("#{TEST_LINES[0]}#{$INPUT_RECORD_SEPARATOR}", io.gets(''))
    assert_equal(1, io.lineno)
    assert_equal(TEST_LINES[0].length + $INPUT_RECORD_SEPARATOR.length, io.pos)

    assert_equal("#{TEST_LINES[1]}#{$INPUT_RECORD_SEPARATOR}", io.gets(''))
    assert_equal(2, io.lineno)
    length = TEST_LINES[0].length + TEST_LINES[1].length + ($INPUT_RECORD_SEPARATOR.length * 2)
    assert_equal(length, io.pos)

    assert_equal(TEST_LINES[2], io.gets(''))
    assert_equal(3, io.lineno)
    assert_equal(paragraphs.length, io.pos)

    assert_predicate(io, :eof?)
    assert_nil(io.gets(''))
  end

  def test_gets_with_chomp
    line_tests_with_chomp
  end

  def test_gets_with_nil_separator_and_chomp
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal(TEST_STRING, io.gets(nil, chomp: true))
  end

  def test_gets_multi_char_seperator
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal('Hell', io.gets('ll'))
    assert_equal("o world#{$INPUT_RECORD_SEPARATOR}this is the second l", io.gets('d l'))
  end

  def test_gets_multi_char_seperator_and_chomp
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal('He', io.gets('ll', chomp: true))
    assert_equal("o world#{$INPUT_RECORD_SEPARATOR}this is the secon", io.gets('d l', chomp: true))
  end

  def test_gets_multi_char_seperator_split
    io = TestAbstractInputStream.new(LONG_LINES.join)
    assert_equal(LONG_LINES[0], io.gets("\r\n"))
    assert_equal(LONG_LINES[1], io.gets("\r\n"))
    assert_equal(LONG_LINES[2], io.gets("\r\n"))
  end

  def test_gets_with_sep_and_limit
    io = TestAbstractInputStream.new(LONG_LINES.join)
    assert_equal('x', io.gets("\r\n", 1))
    assert_equal("#{'x' * 47}\r", io.gets("\r\n", 48))
    assert_equal("\n", io.gets(nil, 1))
    assert_equal('yy', io.gets(nil, 2))
  end

  def test_gets_with_limit
    io = line_tests_with_limit

    assert_predicate(io, :eof?)
    assert_nil(io.gets(8))
  end

  def test_gets_with_utf8_encoding
    io = TestAbstractInputStream.new(TEST_STRING, internal_encoding: Encoding::UTF_8)
    assert_equal(io.gets&.encoding, Encoding::UTF_8)
  end

  def test_gets_with_nil_sep_and_limit_does_not_split_multibyte_chars
    {
      1 => 'é', 2 => 'é', 3 => 'éé', 4 => 'éé', 5 => 'ééé',
      7 => 'ééé👍', 11 => 'ééé👍a'
    }.each do |limit, expected|
      assert_equal(expected, new_utf8_stream.gets(nil, limit), "limit #{limit}")
    end
  end

  def test_gets_with_limit_does_not_split_multibyte_chars
    { 1 => 'é', 3 => 'éé', 7 => 'ééé👍' }.each do |limit, expected|
      assert_equal(expected, new_utf8_stream.gets(limit), "limit #{limit}")
    end
  end

  def test_gets_with_sep_and_limit_does_not_split_multibyte_chars
    { 1 => 'é', 3 => 'éé', 7 => 'ééé👍' }.each do |limit, expected|
      assert_equal(expected, new_utf8_stream.gets("\n", limit), "limit #{limit}")
    end
  end

  def test_gets_with_sep_and_large_limit_keeps_multibyte_line_intact
    io = new_utf8_stream

    assert_equal("ééé👍abc\n", io.gets("\n", 100))
    assert_equal("second line\n", io.gets("\n", 100))
    assert_equal(2, io.lineno)
  end

  def test_gets_with_limit_is_consistent_across_calls
    io = new_utf8_stream

    assert_equal('éé', io.gets(nil, 3))
    assert_equal(4, io.pos)
    assert_equal('é👍', io.gets(nil, 3))
    assert_equal(10, io.pos)
    assert_equal('abc', io.gets(nil, 3))
    assert_equal(13, io.pos)
    assert_equal(3, io.lineno)
  end

  def test_gets_with_limit_does_not_split_utf16_chars
    io = TestAbstractInputStream.new('aéb'.encode('UTF-16LE').b, internal_encoding: Encoding::UTF_16LE)

    assert_equal('a'.encode('UTF-16LE'), io.gets(nil, 1))
    assert_equal(2, io.pos)
    assert_equal('éb'.encode('UTF-16LE'), io.gets(nil, 3))
    assert_equal(6, io.pos)
  end

  def test_gets_with_odd_limit_does_not_split_utf16_chars_in_long_buffer
    data = 'aéb👍'.encode('UTF-16LE') * 20
    io = TestAbstractInputStream.new(data.b, internal_encoding: Encoding::UTF_16LE)

    assert_equal('a'.encode('UTF-16LE'), io.gets(nil, 1))
    assert_equal('é'.encode('UTF-16LE'), io.gets(nil, 1))
    assert_equal('b👍'.encode('UTF-16LE'), io.gets(nil, 3))
    assert_equal(10, io.pos)
  end

  def test_gets_with_limit_does_not_split_shift_jis_chars
    io = TestAbstractInputStream.new('a日本語'.encode('Shift_JIS').b, internal_encoding: Encoding::Shift_JIS)

    assert_equal('a'.encode('Shift_JIS'), io.gets(nil, 1))
    assert_equal('日'.encode('Shift_JIS'), io.gets(nil, 1))
    assert_equal('本'.encode('Shift_JIS'), io.gets(nil, 2))
    assert_equal('語'.encode('Shift_JIS'), io.gets(nil, 1))
    assert_equal(7, io.pos)
  end

  def test_gets_with_limit_completes_char_at_end_of_stream
    io = TestAbstractInputStream.new('é'.b, internal_encoding: Encoding::UTF_8)

    assert_equal('é', io.gets(nil, 1))
    assert_predicate(io, :eof?)
  end

  def test_gets_with_limit_returns_truncated_char_at_end_of_stream
    io = TestAbstractInputStream.new("\xC3".b, internal_encoding: Encoding::UTF_8)

    assert_equal("\xC3".b, io.gets(nil, 1).b)
    assert_predicate(io, :eof?)
  end

  def test_gets_with_limit_does_not_extend_over_invalid_bytes
    io = TestAbstractInputStream.new("\xFF\xFEabc".b, internal_encoding: Encoding::UTF_8)

    assert_equal("\xFF".b, io.gets(nil, 1).b)
    assert_equal("\xFE".b, io.gets(nil, 1).b)
  end

  def test_gets_with_large_limit_does_not_split_multibyte_chars
    io = TestAbstractInputStream.new(('é👍€' * 1000).b, internal_encoding: Encoding::UTF_8)

    # 9 bytes per repetition, so limit 4501 falls inside the 'é' that follows
    # 500 whole repetitions (and 4502 on a character boundary).
    assert_equal("#{'é👍€' * 500}é", io.gets(nil, 4501))
    assert_equal(4502, io.pos)
    assert_equal('👍', io.gets(nil, 4))
  end

  def test_gets_with_limit_after_invalid_bytes_does_not_split_multibyte_chars
    # Truncated and stray bytes before and around the cut must not confuse the
    # search for a character boundary. `each_char` gives the reference framing.
    data = "ab\xE3\x80\x80\x80\xF0\x9F\xC3é\xF0\x9F\x91\x8D\x80\x80\x80\x80€".b
    expected = data.dup.force_encoding(Encoding::UTF_8).each_char.map(&:b)

    io = TestAbstractInputStream.new(data, internal_encoding: Encoding::UTF_8)
    pieces = []
    while (piece = io.gets(nil, 1))
      pieces << piece.b
    end

    assert_equal(expected, pieces)
  end

  def test_gets_with_limit_cuts_on_byte_boundaries_when_binary
    io = TestAbstractInputStream.new(UTF8_STRING.b)

    assert_equal("\xC3".b, io.gets(nil, 1))
    assert_equal(1, io.pos)
  end

  def test_gets_with_zero_limit
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal('', io.gets(0))
    assert_equal(0, io.lineno)
    assert_equal(0, io.pos)

    io.read
    assert_equal('', io.gets(0))
    assert_nil(io.gets)
  end

  def test_gets_returns_nil_when_final_chunk_is_empty
    io = ChunkedInputStream.new(["Hello\n", ''])

    assert_equal("Hello\n", io.gets)
    assert_nil(io.gets)
    assert_equal(1, io.lineno)
    assert_predicate(io, :eof?)
  end

  def test_gets_with_negative_limit_is_unlimited
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal(TEST_LINES[0], io.gets(-1))
    assert_equal(TEST_LINES[1..].join, io.gets(nil, -1))
  end

  def test_each
    io = TestAbstractInputStream.new(TEST_STRING)

    io.each_with_index do |line, index|
      assert_equal(TEST_LINES[index], line)
    end

    assert_predicate(io, :eof?)
    assert_equal(3, io.lineno)
  end

  def test_each_with_nil_separator
    io = TestAbstractInputStream.new(TEST_STRING)

    io.each(nil) do |line|
      assert_equal(TEST_STRING, line)
    end

    assert_predicate(io, :eof?)
    assert_equal(1, io.lineno)
  end

  def test_each_returns_an_enumerator
    io = TestAbstractInputStream.new(TEST_STRING)

    enum = io.each
    assert_instance_of(Enumerator, enum)

    enum.with_index do |line, index|
      assert_equal(TEST_LINES[index], line)
    end

    assert_predicate(io, :eof?)
    assert_equal(3, io.lineno)
  end

  def test_each_with_chomp
    io = TestAbstractInputStream.new(TEST_STRING)

    io.each(chomp: true).with_index do |line, index|
      assert_equal(TEST_LINES[index].chomp, line)
    end

    assert_predicate(io, :eof?)
    assert_equal(3, io.lineno)
  end

  def test_each_with_limit
    io = TestAbstractInputStream.new(TEST_STRING)
    expected_chunks = [
      'Hello wo', "rld\n", 'this is ', 'the seco',
      "nd line\n", 'this is ', 'the last', ' line'
    ]

    io.each_with_index(8) do |chunk, index|
      assert_equal(expected_chunks[index], chunk)
    end

    assert_predicate(io, :eof?)
    assert_equal(expected_chunks.length, io.lineno)
  end

  def test_each_at_eof
    io = TestAbstractInputStream.new(TEST_STRING)
    io.read
    assert_predicate(io, :eof?)

    io.each do |line|
      flunk "Should not yield any lines at EOF, but yielded #{line.inspect}"
    end
  end

  def test_readlines
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal(TEST_LINES, io.readlines)
    assert_predicate(io, :eof?)
    assert_equal(3, io.lineno)

    # readlines should return an empty array if we're already at the end of the stream.
    assert_equal([], io.readlines)
    assert_equal(3, io.lineno)
  end

  def test_readlines_with_utf8_encoding
    io = TestAbstractInputStream.new(TEST_STRING, internal_encoding: Encoding::UTF_8)
    lines = io.readlines
    assert_equal(TEST_LINES, lines)
    lines.each do |line|
      assert_equal(Encoding::UTF_8, line.encoding)
    end
  end

  def test_readlines_with_nil_separator
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal([TEST_STRING], io.readlines(nil))
    assert_predicate(io, :eof?)
    assert_equal(1, io.lineno)
  end

  def test_readlines_with_chomp
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal(TEST_LINES.map(&:chomp), io.readlines(chomp: true))
    assert_predicate(io, :eof?)
    assert_equal(3, io.lineno)
  end

  def test_readlines_with_limit
    io = TestAbstractInputStream.new(TEST_STRING)
    expected_chunks = [
      'Hello wo', "rld\n", 'this is ', 'the seco',
      "nd line\n", 'this is ', 'the last', ' line'
    ]

    assert_equal(expected_chunks, io.readlines(8))
    assert_predicate(io, :eof?)
    assert_equal(expected_chunks.length, io.lineno)
  end

  def test_readline
    io = line_tests(method_name: :readline)

    # readline should raise EOFError if we're already at the end of the stream.
    assert_raises(EOFError) { io.readline }
    assert_equal(3, io.lineno)
  end

  def test_readline_with_chomp
    line_tests_with_chomp(method_name: :readline)
  end

  def test_readline_with_limit
    io = line_tests_with_limit(method_name: :readline)

    assert_predicate(io, :eof?)
    assert_raises(EOFError) { io.readline(8) }
  end

  def test_readline_with_utf8_encoding
    io = TestAbstractInputStream.new(TEST_STRING, internal_encoding: Encoding::UTF_8)
    assert_equal(io.readline.encoding, Encoding::UTF_8)
  end

  def test_set_encoding
    io = TestAbstractInputStream.new(TEST_STRING)
    assert_equal(Encoding::ASCII_8BIT, io.read(1).encoding)
    io.set_encoding(Encoding::ASCII_8BIT, Encoding::UTF_8)
    assert_equal(Encoding::UTF_8, io.read(1).encoding)
    assert_equal(Encoding::UTF_8, io.gets&.encoding)
  end

  private

  def new_utf8_stream
    TestAbstractInputStream.new(UTF8_STRING.b, internal_encoding: Encoding::UTF_8)
  end

  def line_tests(method_name: :gets)
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal(TEST_LINES[0], io.send(method_name))
    assert_equal(1, io.lineno)
    assert_equal(TEST_LINES[0].length, io.pos)
    assert_equal(TEST_LINES[1], io.send(method_name))
    assert_equal(2, io.lineno)
    assert_equal(TEST_LINES[2], io.send(method_name))
    assert_equal(3, io.lineno)
    assert_predicate(io, :eof?)

    io
  end

  def line_tests_with_chomp(method_name: :gets)
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal(TEST_LINES[0].chomp, io.send(method_name, chomp: true))
    assert_equal(TEST_LINES[1].chomp, io.send(method_name, chomp: true))
    assert_equal(TEST_LINES[2], io.send(method_name, chomp: true))
  end

  def line_tests_with_limit(method_name: :gets)
    io = TestAbstractInputStream.new(TEST_STRING)

    [
      'Hello wo', "rld\n", 'this is ', 'the seco',
      "nd line\n", 'this is ', 'the last', ' line'
    ].each do |chunk|
      assert_equal(chunk, io.send(method_name, 8))
    end

    io
  end
end
