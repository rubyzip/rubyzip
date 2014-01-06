#!/usr/bin/env ruby
require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start do
  add_filter '/test'
end
Dir.chdir File.join(File.dirname(__FILE__))

$VERBOSE = true

require 'ioextrastest'
require 'ziptest'
require 'zipfilesystemtest'
