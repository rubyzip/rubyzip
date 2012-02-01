#!/usr/bin/env ruby

$VERBOSE = true

$: << "../lib"

require 'test/unit'
require 'zip/stdrubyext'

class StringExtensionsTest < Test::Unit::TestCase

  def test_ensure_end
    assert_equal("hello!", "hello!".ensure_end("!"))
    assert_equal("hello!", "hello!".ensure_end("o!"))
    assert_equal("hello!", "hello".ensure_end("!"))
    assert_equal("hello!", "hel".ensure_end("lo!"))
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
