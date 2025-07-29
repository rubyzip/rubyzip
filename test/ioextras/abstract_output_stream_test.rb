# frozen_string_literal: true

require_relative '../test_helper'

require 'zip/ioextras'

class AbstractOutputStreamTest < Minitest::Test
  class TestOutputStream
    include ::Zip::IOExtras::AbstractOutputStream

    attr_accessor :buffer

    def initialize
      @buffer = +''
    end

    def <<(data)
      @buffer << data
      self
    end
  end

  def setup
    @output_stream = TestOutputStream.new
  end

  def test_write
    str1 = 'a little string'
    count = @output_stream.write(str1)
    assert_equal(str1, @output_stream.buffer)
    assert_equal(str1.length, count)

    str2 = '. a little more'
    count = @output_stream.write(str2)
    assert_equal(str1 + str2, @output_stream.buffer)
    assert_equal(str2.length, count)
  end

  def test_print
    @output_stream.print('hello')
    assert_equal('hello', @output_stream.buffer)

    @output_stream.print(' world.')
    assert_equal('hello world.', @output_stream.buffer)

    @output_stream.print(' You ok ', 'out ', 'there?')
    assert_equal('hello world. You ok out there?', @output_stream.buffer)

    @output_stream.buffer = +''
    @output_stream.print(20)
    assert_equal('20', @output_stream.buffer)
  end

  def test_printf
    @output_stream.printf('%<dec>d %<hex>04x', dec: 123, hex: 123)
    assert_equal('123 007b', @output_stream.buffer)
  end

  def test_putc
    @output_stream.putc('A')
    assert_equal('A', @output_stream.buffer)
    @output_stream.putc(65)
    assert_equal('AA', @output_stream.buffer)
  end

  def test_puts
    @output_stream.puts
    assert_equal("\n", @output_stream.buffer)

    @output_stream.puts('hello', 'world')
    assert_equal("\nhello\nworld\n", @output_stream.buffer)

    @output_stream.buffer = +''
    @output_stream.puts("hello\n", "world\n")
    assert_equal("hello\nworld\n", @output_stream.buffer)

    @output_stream.buffer = +''
    @output_stream.puts(%W[hello\n world\n])
    assert_equal("hello\nworld\n", @output_stream.buffer)

    @output_stream.buffer = +''
    @output_stream.puts(%W[hello\n world\n], 'bingo')
    assert_equal("hello\nworld\nbingo\n", @output_stream.buffer)

    @output_stream.buffer = +''
    @output_stream.puts(16, 20, 50, 'hello')
    assert_equal("16\n20\n50\nhello\n", @output_stream.buffer)
  end
end
