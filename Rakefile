# Rakefile for RubyGems      -*- ruby -*-

require 'rubygems'
require 'rake/clean'
require 'rake/testtask'
require 'rake/packagetask'

PKG_NAME = 'rubyzip'
PKG_VERSION = '0.5.6'

CLOBBER.add File.readlines('test/.cvsignore').map { |f| 'test/'+f }

task :default => [:test]

desc "Run unit tests"
task :test do
  ruby %{-C test alltests.rb}
end

# Shortcuts for test targets
task :ut => [:test]

#task :gemtest do
#  ruby %{-Ilib -rscripts/runtest -e 'run_tests("test/test_gempaths.rb", true)'}
#end

Rake::PackageTask.new("package") do |p|
  p.name = PKG_NAME
  p.version = PKG_VERSION
  p.need_tar = true
  p.need_zip = true
  p.package_files.include(
    "NEWS", "README", "Rakefile", "TODO", 
    "install.rb",
    "rubyzip.gemspec",
    "samples/*.rb",
    "zip/*.rb",
    "test/*"
    )
end
