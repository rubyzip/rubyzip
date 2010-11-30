require 'rubygems'
require 'rake/testtask'

task :default => [:test]

Rake::TestTask.new(:test) do |test|
  test.libs << File.join(File.dirname(__FILE__), 'lib')
  test.libs << File.join(File.dirname(__FILE__), 'test')
  test.pattern = File.join(File.dirname(__FILE__), 'test/**/*.rb')
  test.verbose = true
  Dir.chdir File.join(File.dirname(__FILE__), 'test')
end

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.verbose = true
  spec.pattern = FileList['spec/**/*_spec.rb']
end

task :default => :spec
