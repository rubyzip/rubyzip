PKG_VERSION = File.read('lib/zip/zip.rb').match(/\s+VERSION\s*=\s*'(.*)'/)[1]

spec = Gem::Specification.new do |s|
  s.name = 'rubyzip'
  s.version = PKG_VERSION
  s.author = "Alan Harper"
  s.email = "alan@aussiegeek.net"
  s.homepage = "http://github.com/aussiegeek/rubyzip"
  s.platform = Gem::Platform::RUBY
  s.summary = "rubyzip is a ruby module for reading and writing zip files"
  s.files = Dir.glob("{samples,lib}/**/*.rb") + %w{ README NEWS TODO Rakefile }
  s.licenses = ["MIT"]
  s.test_files = Dir.glob("spec/**/*.rb")
  s.require_path = 'lib'
  s.required_ruby_version = '>= 1.8.6'

  s.add_development_dependency(%q<bundler>, ["~> 1.0.0"])
  s.add_development_dependency(%q<rspec>, ["~> 2.2.0"])
end
