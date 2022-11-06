# frozen_string_literal: true

require_relative 'lib/zip/version'

Gem::Specification.new do |s|
  s.name          = 'rubyzip'
  s.version       = ::Zip::VERSION
  s.authors       = ['Robert Haines', 'John Lees-Miller', 'Alexander Simonov']
  s.email         = [
    'hainesr@gmail.com', 'jdleesmiller@gmail.com', 'alex@simonov.me'
  ]
  s.homepage      = 'http://github.com/rubyzip/rubyzip'
  s.platform      = Gem::Platform::RUBY
  s.summary       = 'rubyzip is a ruby module for reading and writing zip files'
  s.files         = Dir.glob('{samples,lib}/**/*.rb') +
                    %w[README.md Changelog.md Rakefile rubyzip.gemspec]
  s.require_paths = ['lib']
  s.license       = 'BSD-2-Clause'

  s.metadata      = {
    'bug_tracker_uri'   => 'https://github.com/rubyzip/rubyzip/issues',
    'changelog_uri'     => "https://github.com/rubyzip/rubyzip/blob/v#{s.version}/Changelog.md",
    'documentation_uri' => "https://www.rubydoc.info/gems/rubyzip/#{s.version}",
    'source_code_uri'   => "https://github.com/rubyzip/rubyzip/tree/v#{s.version}",
    'wiki_uri'          => 'https://github.com/rubyzip/rubyzip/wiki'
  }

  s.required_ruby_version = '>= 2.5'

  s.add_development_dependency 'minitest', '~> 5.4'
  s.add_development_dependency 'rake', '~> 12.3.3'
  s.add_development_dependency 'rdoc', '~> 6.4.0'
  s.add_development_dependency 'rubocop', '~> 1.12.0'
  s.add_development_dependency 'rubocop-performance', '~> 1.10.0'
  s.add_development_dependency 'rubocop-rake', '~> 0.5.0'
  s.add_development_dependency 'simplecov', '~> 0.18.0'
  s.add_development_dependency 'simplecov-lcov', '~> 0.8'
end
