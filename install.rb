#!/usr/bin/env ruby

$VERBOSE = true

require 'rbconfig'
require 'find'
require 'ftools'

include Config

files = %w{ zip.rb filearchive.rb ziprequire.rb }

files.each { 
  |filename|
  installPath = File.join(CONFIG["sitelibdir"], filename)
  File::install(filename, installPath, 0644, true)
}
