#!/usr/bin/env ruby

system("zip example.zip example.rb NEWS")

require 'zip'

####### Using ZipInputStream alone: #######

Zip::ZipInputStream.open("example.zip") {
  |zis|
  entry = zis.getNextEntry
  puts "********* Zip entry '#{entry.name} (#{entry.size} bytes)' contains: ********"
  puts zis.read
  entry = zis.getNextEntry
  puts "********* Zip entry '#{entry.name} (#{entry.size} bytes)' contains: ********"
  puts zis.read
}



####### Using SimpleZipFile to read the directory of a zip file: #######

zf = Zip::SimpleZipFile.new("example.zip")
zf.each_with_index {
  |entry, index|
  
  puts "entry #{index} is #{entry.name}, size = #{entry.size}, compressed size = #{entry.compressedSize}"
  # use zf.getInputStream(entry) to get a ZipInputStream for the entry
  # entry can be the ZipEntry object or any object which has a to_s method that
  # returns the name of the entry.
}

####### Using ZipOutputStream to write a zip file: #######

Zip::ZipOutputStream.open("exampleout.zip") {
  |zos|
  zos.putNextEntry("the first little entry")
  zos.puts "Hello hello hello hello hello hello hello hello hello"

  zos.putNextEntry("the second little entry")
  zos.puts "Hello again"

  # Use rubyzip or your zip client of choice to verify
  # the contents of exampleout.zip
}



# For other examples, look at zip.rb and ziptest.rb
