#!/usr/bin/env ruby

$VERBOSE = true

$: << "../lib"

require 'test/unit'
require 'zip/stdrubyext'

class ModuleTest < Test::Unit::TestCase

  def test_select_map
    assert_equal([2, 4, 8, 10], [1, 2, 3, 4, 5].select_map { |e| e == 3 ? nil : 2*e })
  end
  
end

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
