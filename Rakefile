# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'rdoc/task'
require 'rubocop/rake_task'

task default: :test

Rake::TestTask.new(:test) do |test|
  test.libs << 'lib'
  test.libs << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

RDoc::Task.new do |rdoc|
  rdoc.main = 'README.md'
  rdoc.rdoc_files.include('README.md', 'lib/**/*.rb')
  rdoc.options << '--markup=markdown'
  rdoc.options << '--tab-width=2'
  rdoc.options << "-t Rubyzip version #{Zip::VERSION}"
end

RuboCop::RakeTask.new
