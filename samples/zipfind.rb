#!/usr/bin/env ruby

$VERBOSE = true

$: << ".."

require 'zip'
require 'find'

module ZipFind
  def self.find(path, zipfileRegex, fileNameRegex, breakOnMatch = true)
    startedAt = Time.now
    archivesExamined = 0
    entriesExamined = 0
    entriesFound = 0
    Find.find(path) {
      |file|
      archivesExamined = archivesExamined.next
      if (file =~ zipfileRegex && File.readable?(file))
	Zip::ZipFile.foreach(file) {
	  |entry|
	  entriesExamined = entriesExamined.next
	  if entry.to_s =~ fileNameRegex
	    reportEntryFound(file, entry)
	    entriesFound = entriesFound.next
	    return if breakOnMatch
	  end
	} rescue Errno::EACCES
      end
    }
  ensure
    reportStats(startedAt, archivesExamined, entriesExamined, entriesFound)
  end
  
  def self.reportEntryFound(zipfileName, entry)
    puts "Found entry #{entry} in zip file #{zipfileName}"
  end

  def self.reportStats(startedAt, archivesExamined, 
		       entriesExamined, entriesFound)
    seconds = (Time.now - startedAt).round
    puts ("Found #{entriesFound} entries after examining #{entriesExamined} " +
	  "entries in #{archivesExamined} archives in #{seconds} seconds.")
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
