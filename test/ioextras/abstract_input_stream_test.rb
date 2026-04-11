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

  class TestAbstractInputStream
    include ::Zip::IOExtras::AbstractInputStream

    def initialize(string)
      super()
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

  LONG_LINES = [
    "#{'x' * 48}\r\n",
    "#{'y' * 49}\r\n",
    'rest'
  ].freeze

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

  def test_each_line
    io = TestAbstractInputStream.new(TEST_STRING)

    line_num = 0
    io.each_line do |line|
      assert_equal(TEST_LINES[line_num], line)
      line_num += 1
    end
  end

  def test_readlines
    io = TestAbstractInputStream.new(TEST_STRING)

    assert_equal(TEST_LINES, io.readlines)
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

  private

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
