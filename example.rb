#!/usr/bin/env ruby

system("zip example.zip example.rb NEWS")

require 'zip'

## Using ZipInputStream alone:

ZipInputStream.open("example.zip") {
  |zis|
  entry = zis.getNextEntry
  puts "********* Zip entry '#{entry.name} (#{entry.size} bytes)' contains: ********"
  puts zis.read
  entry = zis.getNextEntry
  puts "********* Zip entry '#{entry.name} (#{entry.size} bytes)' contains: ********"
  puts zis.read
}


zf = ZipFile.new("example.zip")
zf.each_with_index {
  |entry, index|
  
  puts "entry #{index} is #{entry.name}, size = #{entry.size}, compressed size = #{entry.compressedSize}"
  # use zf.getInputStream(entry) to get a ZipInputStream for the entry
  # entry can be the ZipEntry object or any object which has a to_s method that
  # returns the name of the entry.
}

# For other examples, look at zip.rb and ziptest.rb
