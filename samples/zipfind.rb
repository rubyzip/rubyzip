#!/usr/bin/env ruby

$VERBOSE = true

$: << ".."

require 'zip'
require 'find'

module Zip
  module ZipFind
    def self.find(path, zipFilePattern = /\.zip$/i)
      Find.find(path) {
	|fileName|
	yield(fileName)
	if fileName =~ zipFilePattern && File.file?(fileName)
	  begin
	    Zip::ZipFile.foreach(fileName)  {
	      |zipEntry|
	      yield(fileName + File::SEPARATOR + zipEntry.to_s)
	    }
	  rescue Errno::EACCES => ex
	    puts ex
	  end
	end
      }
    end

    def self.findFile(path, fileNamePattern, zipFilePattern = /\.zip$/i)
      self.find(path, zipFilePattern) {
	|fileName|
	yield(fileName) if fileName =~ fileNamePattern
      }
    end

  end
end

if __FILE__ == $0
  module ZipFindConsoleRunner
    
    PATH_ARG_INDEX = 0;
    FILENAME_PATTERN_ARG_INDEX = 1;
    ZIPFILE_PATTERN_ARG_INDEX = 2;
    
    def self.run(args)
      checkArgs(args)
      Zip::ZipFind.findFile(args[PATH_ARG_INDEX], 
			    args[FILENAME_PATTERN_ARG_INDEX],
			    args[ZIPFILE_PATTERN_ARG_INDEX]) {
	|fileName|
	reportEntryFound fileName
      }
    end
    
    def self.checkArgs(args)
      if (args.size != 3)
	usage
	exit
      end
    end

    def self.usage
      puts "Usage: #{$0} PATH ZIPFILENAME_PATTERN FILNAME_PATTERN"
    end
    
    def self.reportEntryFound(fileName)
      puts fileName
    end
    
  end

  ZipFindConsoleRunner.run(ARGV)
end
