lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'zip/version'

Gem::Specification.new do |s|
  s.name                  = 'rubyzip'
  s.version               = ::Zip::VERSION
  s.authors               = ['Robert Haines', 'John Lees-Miller', 'Alexander Simonov']
  s.email                 = [
    'hainesr@gmail.com', 'jdleesmiller@gmail.com', 'alex@simonov.me'
  ]
  s.homepage              = 'http://github.com/rubyzip/rubyzip'
  s.platform              = Gem::Platform::RUBY
  s.summary               = 'rubyzip is a ruby module for reading and writing zip files'
  s.files                 = Dir.glob('{samples,lib}/**/*.rb') + %w[README.md TODO Rakefile]
  s.require_paths         = ['lib']
  s.license               = 'BSD 2-Clause'
  s.metadata              = {
    'bug_tracker_uri'       => 'https://github.com/rubyzip/rubyzip/issues',
    'changelog_uri'         => "https://github.com/rubyzip/rubyzip/blob/v#{s.version}/Changelog.md",
    'documentation_uri'     => "https://www.rubydoc.info/gems/rubyzip/#{s.version}",
    'source_code_uri'       => "https://github.com/rubyzip/rubyzip/tree/v#{s.version}",
    'wiki_uri'              => 'https://github.com/rubyzip/rubyzip/wiki',
    'rubygems_mfa_required' => 'true'
  }
  s.required_ruby_version = '>= 2.4'
  s.add_development_dependency 'minitest', '~> 5.4'
  s.add_development_dependency 'pry', '~> 0.10'
  s.add_development_dependency 'rake', '~> 12.3', '>= 12.3.3'
  s.add_development_dependency 'rubocop', '~> 0.79'

  s.post_install_message = <<~ENDBANNER
    RubyZip 3.0 is coming!
    **********************

    The public API of some Rubyzip classes has been modernized to use named
    parameters for optional arguments. Please check your usage of the
    following classes:
      * `Zip::File`
      * `Zip::Entry`
      * `Zip::InputStream`
      * `Zip::OutputStream`
      * `Zip::DOSTime`

    Run your test suite with the `RUBYZIP_V3_API_WARN` environment
    variable set to see warnings about usage of the old API. This will
    help you to identify any changes that you need to make to your code.
    See https://github.com/rubyzip/rubyzip/wiki/Updating-to-version-3.x for
    more information.

    Please ensure that your Gemfiles and .gemspecs are suitably restrictive
    to avoid an unexpected breakage when 3.0 is released (e.g. ~> 2.3.0).
    See https://github.com/rubyzip/rubyzip for details. The Changelog also
    lists other enhancements and bugfixes that have been implemented since
    version 2.3.0.
  ENDBANNER
end
