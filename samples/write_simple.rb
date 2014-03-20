#!/usr/bin/env ruby

$: << "../lib"

require 'rubyzip/rubyzip'

include RubyZip

OutputStream.open('simple.zip') {
  |zos|
  ze = zos.put_next_entry 'entry.txt'
  zos.puts "Hello world"
}
