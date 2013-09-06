#-*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'zip/version'

spec = Gem::Specification.new do |s|
  s.name                  = 'rubyzip'
  s.version               = ::Zip::VERSION
  s.authors               = ["Alexander Simonov"]
  s.email                 = ["alex@simonov.me"]
  s.homepage              = 'http://github.com/rubyzip/rubyzip'
  s.platform              = Gem::Platform::RUBY
  s.summary               = 'rubyzip is a ruby module for reading and writing zip files'
  s.files                 = Dir.glob("{samples,lib}/**/*.rb") + %w{ README.md TODO Rakefile }
  s.require_paths         = ['lib']
  s.required_ruby_version = '>= 1.9.2'
end
