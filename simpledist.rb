#!/usr/bin/env ruby

CVSROOT='-dthomas@cvs.rubyzip.sf.net:/cvsroot/rubyzip'
MODULE='rubyzip'
MODULE_RUNTEST=MODULE+"RunTest"
TESTSUITE='ziptest.rb'

TMPDIR = [ ENV['TMPDIR'], ENV['TMP'], ENV['TEMP'], "/tmp"].compact.first
Dir.chdir TMPDIR

raise "Clean up failed" unless system("rm -rf #{MODULE}")
raise "CVS co failed"   unless system("cvs #{CVSROOT} co #{MODULE}")
Dir.chdir MODULE

raise "Failed to create changelog" unless system("cvs2cl.pl --prune")

log = `cvs log`

raise "Failed to obtain version number from cvs" unless 
  log.grep(/release-\d-\d-\d\:/)[0] =~ (/release-(\d)-(\d)-(\d)\:/)

versionString = "#{$1}.#{$2}.#{$3}"

raise "removal of CVS files failed" unless system('rm -rf `find . -name CVS -or -name .cvsignore`')

Dir.chdir ".."

mainFiles = `find #{MODULE}`.split.sort

archiveName = "#{MODULE}-#{versionString}.tar.gz"

raise "Failed to created main archive" unless
  system("tar cvfz #{archiveName} #{MODULE}")

raise "Clean up failed" unless system("rm -rf #{MODULE_RUNTEST}")
raise "copy to testdir failed" unless 
  system("cp -r #{MODULE} #{MODULE_RUNTEST}")
Dir.chdir MODULE_RUNTEST

raise "test suite failed" unless system("ruby #{TESTSUITE}")

Dir.chdir "../#{MODULE}"

raise "create test data files failed" unless 
  system("ruby #{TESTSUITE} recreateonly")

Dir.chdir ".."

testFiles = `find #{MODULE}`.split.sort - mainFiles


testArchiveName = "#{MODULE}-testdata-#{versionString}.tar.gz"

raise "Could not create testdata archive" unless
  system("tar cvfz #{testArchiveName} #{testFiles.join(" ")}")

puts "\n\nTwo archives created:\n #{TMPDIR}/#{archiveName}\n #{TMPDIR}/#{testArchiveName}"

