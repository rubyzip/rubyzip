# Rakefile for RubyGems      -*- ruby -*-

require 'rubygems'
require 'rake/clean'
require 'rake/testtask'
require 'rake/packagetask'
require 'rake/gempackagetask'

PKG_NAME = 'rubyzip'
PKG_VERSION = '0.5.7'

CLOBBER.add File.readlines('test/.cvsignore').map { |f| 'test/'+f }

task :default => [:test]

desc "Run unit tests"
task :test do
  ruby %{-C test alltests.rb}
end

# Shortcuts for test targets
task :ut => [:test]

spec = Gem::Specification.new do |s|
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.author = "Thomas Sondergaard"
  s.email = "thomas(at)sondergaard.cc"
  s.homepage = "http://rubyzip.sourceforge.net/"
  s.platform = Gem::Platform::RUBY
  s.summary = "rubyzip is a ruby module for reading and writing zip files"
  s.files = Dir.glob("{samples,lib,test,docs}/**/*").delete_if {|item| item.include?("CVS") || item.include?("rdoc") || item =~ /~$/ }
  s.require_path = 'lib'
  s.autorequire = 'zip/zip'
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end
