require 'rubygems'
require 'rake/testtask'

task :default => [:test]

desc "Run unit tests"
task :test do
  ruby %{-C test alltests.rb}
end
