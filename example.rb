#!/usr/bin/env ruby

system("zip example.zip example.rb")

require 'zip'

ZipInputStream.open("example.zip") {
  |zis|
  entry = zis.getNextEntry
  puts "Zip entry '#{entry.name}' contains:"
  puts zis.read
}

# For other examples, look at zip.rb and ziptest.rb
