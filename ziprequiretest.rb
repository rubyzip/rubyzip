#!/usr/bin/env ruby

$VERBOSE = true

require 'rubyunit'
require 'ziprequire'
$: << 'rubycode.zip'

Dir.chdir "test"

class ZipRequireTest < RUNIT::TestCase
  def test_require
    assert(require 'notzippedruby')
    assert(!require('notzippedruby'))

    assert(require 'zippedruby1')
    assert(!require('zippedruby1'))

    assert(require 'zippedruby2')
    assert(!require('zippedruby2'))

    c1 = NotZippedRuby.new
    assert(c1.returnTrue)
    assert(ZippedRuby1.returnTrue)
    assert(!ZippedRuby2.returnFalse)
  end

  def test_getResource
    getResource("aResource.txt") {
      |f|
      assert_equals("Nothing exciting in this file!", f.read)
    }
  end
end
