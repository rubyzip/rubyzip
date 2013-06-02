#!/usr/bin/env ruby

$VERBOSE = true

$: << "../lib"

require 'test/unit'
require 'zip/ioextras'

include ::Zip::IOExtras

class FakeIOTest < Test::Unit::TestCase
  class FakeIOUsingClass
    include FakeIO
  end

  def test_kind_of?
    obj = FakeIOUsingClass.new
    
    assert(obj.kind_of?(Object))
    assert(obj.kind_of?(FakeIOUsingClass))
    assert(obj.kind_of?(IO))
    assert(!obj.kind_of?(Fixnum))
    assert(!obj.kind_of?(String))
  end
end

class AbstractInputStreamTest < Test::Unit::TestCase
  # AbstractInputStream subclass that provides a read method
  
  TEST_LINES = [ "Hello world#{$/}", 
    "this is the second line#{$/}", 
    "this is the last line"]
  TEST_STRING = TEST_LINES.join
  class TestAbstractInputStream 
    include AbstractInputStream
    def initialize(aString)
      super()
      @contents = aString
      @readPointer = 0
    end

    def sysread(charsToRead, buf = nil)
      retVal=@contents[@readPointer, charsToRead]
      @readPointer+=charsToRead
      return retVal
    end

    def produce_input
      sysread(100)
    end

    def input_finished?
      @contents[@readPointer] == nil
    end
  end

  def setup
    @io = TestAbstractInputStream.new(TEST_STRING)
  end
  
  def test_gets
    assert_equal(TEST_LINES[0], @io.gets)
    assert_equal(1, @io.lineno)
    assert_equal(TEST_LINES[0].length, @io.pos)
    assert_equal(TEST_LINES[1], @io.gets)
    assert_equal(2, @io.lineno)
    assert_equal(TEST_LINES[2], @io.gets)
    assert_equal(3, @io.lineno)
    assert_equal(nil, @io.gets)
    assert_equal(4, @io.lineno)
  end

  def test_getsMultiCharSeperator
    assert_equal("Hell", @io.gets("ll"))
    assert_equal("o world#{$/}this is the second l", @io.gets("d l"))
  end

  LONG_LINES = [
    'x'*48 + "\r\n",
    'y'*49 + "\r\n",
    'rest',
  ]
  def test_getsMulitCharSeperator_split
    io = TestAbstractInputStream.new(LONG_LINES.join)
    assert_equal(LONG_LINES[0], io.gets("\r\n"))
    assert_equal(LONG_LINES[1], io.gets("\r\n"))
    assert_equal(LONG_LINES[2], io.gets("\r\n"))
  end

  def test_getsWithSepAndIndex
    io = TestAbstractInputStream.new(LONG_LINES.join)
    assert_equal('x', io.gets("\r\n", 1))
    assert_equal('x'*47 + "\r", io.gets("\r\n", 48))
    assert_equal("\n", io.gets(nil, 1))
    assert_equal('yy', io.gets(nil, 2))
  end

  def test_getsWithIndex
    assert_equal(TEST_LINES[0], @io.gets(100))
    assert_equal('this', @io.gets(4))
  end

  def test_each_line
    lineNumber=0
    @io.each_line {
      |line|
      assert_equal(TEST_LINES[lineNumber], line)
      lineNumber+=1
    }
  end

  def test_readlines
    assert_equal(TEST_LINES, @io.readlines)
  end

  def test_readline
    test_gets
    begin
      @io.readline
      fail "EOFError expected"
      rescue EOFError
    end
  end
end

class AbstractOutputStreamTest < Test::Unit::TestCase
  class TestOutputStream
    include AbstractOutputStream

    attr_accessor :buffer

    def initialize
      @buffer = ""
    end

    def << (data)
      @buffer << data
      self
    end
  end

  def setup
    @output_stream = TestOutputStream.new

    @origCommaSep = $,
    @origOutputSep = $\
  end

  def teardown
    $, = @origCommaSep
    $\ = @origOutputSep
  end

  def test_write
    count = @output_stream.write("a little string")
    assert_equal("a little string", @output_stream.buffer)
    assert_equal("a little string".length, count)

    count = @output_stream.write(". a little more")
    assert_equal("a little string. a little more", @output_stream.buffer)
    assert_equal(". a little more".length, count)
  end
  
  def test_print
    $\ = nil # record separator set to nil
    @output_stream.print("hello")
    assert_equal("hello", @output_stream.buffer)

    @output_stream.print(" world.")
    assert_equal("hello world.", @output_stream.buffer)
    
    @output_stream.print(" You ok ",  "out ", "there?")
    assert_equal("hello world. You ok out there?", @output_stream.buffer)

    $\ = "\n"
    @output_stream.print
    assert_equal("hello world. You ok out there?\n", @output_stream.buffer)

    @output_stream.print("I sure hope so!")
    assert_equal("hello world. You ok out there?\nI sure hope so!\n", @output_stream.buffer)

    $, = "X"
    @output_stream.buffer = ""
    @output_stream.print("monkey", "duck", "zebra")
    assert_equal("monkeyXduckXzebra\n", @output_stream.buffer)

    $\ = nil
    @output_stream.buffer = ""
    @output_stream.print(20)
    assert_equal("20", @output_stream.buffer)
  end
  
  def test_printf
    @output_stream.printf("%d %04x", 123, 123)
    assert_equal("123 007b", @output_stream.buffer)
  end
  
  def test_putc
    @output_stream.putc("A")
    assert_equal("A", @output_stream.buffer)
    @output_stream.putc(65)
    assert_equal("AA", @output_stream.buffer)
  end

  def test_puts
    @output_stream.puts
    assert_equal("\n", @output_stream.buffer)

    @output_stream.puts("hello", "world")
    assert_equal("\nhello\nworld\n", @output_stream.buffer)

    @output_stream.buffer = ""
    @output_stream.puts("hello\n", "world\n")
    assert_equal("hello\nworld\n", @output_stream.buffer)
    
    @output_stream.buffer = ""
    @output_stream.puts(["hello\n", "world\n"])
    assert_equal("hello\nworld\n", @output_stream.buffer)

    @output_stream.buffer = ""
    @output_stream.puts(["hello\n", "world\n"], "bingo")
    assert_equal("hello\nworld\nbingo\n", @output_stream.buffer)

    @output_stream.buffer = ""
    @output_stream.puts(16, 20, 50, "hello")
    assert_equal("16\n20\n50\nhello\n", @output_stream.buffer)
  end
end


# Copyright (C) 2002-2004 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
