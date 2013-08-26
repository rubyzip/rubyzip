require 'bundler/gem_tasks'
require 'rake/testtask'

task :default => :test

Rake::TestTask.new(:test) do |test|
  test.libs << File.join(File.dirname(__FILE__), 'lib')
  test.libs << File.join(File.dirname(__FILE__), 'test')
  test.pattern = File.join(File.dirname(__FILE__), 'test/alltests.rb')
  test.verbose = true

end

