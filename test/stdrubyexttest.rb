#!/usr/bin/env ruby

$VERBOSE = true

$: << ".."

require 'rubyunit'
require 'zip/stdrubyext'

class ModuleTest < RUNIT::TestCase

  def test_select_map
    assert_equals([2, 4, 8, 10], [1, 2, 3, 4, 5].select_map { |e| e == 3 ? nil : 2*e })
  end
  
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
