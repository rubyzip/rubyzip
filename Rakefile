require 'rubygems'
require 'rake/testtask'

task :default => [:test]

Rake::TestTask.new(:test) do |test|
  test.libs << File.join(File.dirname(__FILE__), 'lib')
  test.libs << File.join(File.dirname(__FILE__), 'test')
  test.test_files = Dir.glob(File.join(File.dirname(__FILE__), 'test/**/*.rb'))
  test.verbose = true
  Dir.chdir File.join(File.dirname(__FILE__), 'test')
end

