#!/usr/bin/env ruby

$VERBOSE = true

require 'stdrubyext'
require 'ziptest'
require 'zipfilesystemtest'
require 'ziprequiretest'

if __FILE__ == $0
  Dir.chdir "test"
end
