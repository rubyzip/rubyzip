#!/usr/bin/env ruby

$VERBOSE = true

$: << ".."

require 'zip'
require 'find'

module ZipFind
  def self.find(path, zipfileRegex, fileNameRegex, breakOnMatch = true)
    Find.find(path) {
      |file|
      if (file =~ zipfileRegex && File.readable?(file))
	Zip::ZipFile.foreach(file) {
	  |entry|
	  if entry.to_s =~ fileNameRegex
	    reportEntryFound(file, entry)
	    return if breakOnMatch
	  end
	} rescue Errno::EACCES
      end
    }
  end
  
  def self.reportEntryFound(zipfileName, entry)
    puts "Found entry #{entry} in zip file #{zipfileName}"
  end
  
  def self.usage
    puts "Usage: #{$0} PATH ZIPFILENAME_PATTERN FILNAME_PATTERN"
  end
  
end

if __FILE__ == $0
  if (ARGV.size != 3)
    usage()
    exit
  end
  ZipFind.find(ARGV[0], 
	       Regexp.new(ARGV[1], Regexp::IGNORECASE), 
	       Regexp.new(ARGV[2], Regexp::IGNORECASE))
end
