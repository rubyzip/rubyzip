#-*- encoding: utf-8 -*-

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'zip/version'

Gem::Specification.new do |s|
  s.name                  = 'rubyzip'
  s.version               = ::Zip::VERSION
  s.authors               = ['Alexander Simonov']
  s.email                 = ['alex@simonov.me']
  s.homepage              = 'http://github.com/rubyzip/rubyzip'
  s.platform              = Gem::Platform::RUBY
  s.summary               = 'rubyzip is a ruby module for reading and writing zip files'
  s.files                 = Dir.glob('{samples,lib}/**/*.rb') + %w[README.md TODO Rakefile]
  s.require_paths         = ['lib']
  s.license               = 'BSD 2-Clause'
  s.metadata              = {
    'bug_tracker_uri'   => 'https://github.com/rubyzip/rubyzip/issues',
    'changelog_uri'     => "https://github.com/rubyzip/rubyzip/blob/v#{s.version}/Changelog.md",
    'documentation_uri' => "https://www.rubydoc.info/gems/rubyzip/#{s.version}",
    'source_code_uri'   => "https://github.com/rubyzip/rubyzip/tree/v#{s.version}",
    'wiki_uri'          => 'https://github.com/rubyzip/rubyzip/wiki'
  }
  s.required_ruby_version = '>= 2.4'
  s.add_development_dependency 'rake', '~> 10.3'
  s.add_development_dependency 'pry', '~> 0.10'
  s.add_development_dependency 'minitest', '~> 5.4'
  s.add_development_dependency 'coveralls', '~> 0.7'
  s.add_development_dependency 'rubocop', '~> 0.49.1'
end
