$:.unshift '../lib'
require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'rubyzip'
  s.version = "0.5.6"
  s.author = "Thomas Sondergaard"
  s.email = "thomas(at)sondergaard.cc"
  s.homepage = "http://rubyzip.sourceforge.net/"
  s.platform = Gem::Platform::RUBY
  s.summary = "rubyzip is a ruby module for reading and writing zip files"
  s.files = Dir.glob("{samples,zip,docs}/**/*").delete_if {|item| item.include?("CVS") || item.include?("rdoc") || item =~ /~$/ }
  s.require_path = '.'
  s.autorequire = 'zip/zip'
end

if $0==__FILE__
  Gem::Builder.new(spec).build
end

