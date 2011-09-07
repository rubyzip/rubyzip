spec = Gem::Specification.new do |s|
  pkg_version = File.read('lib/zip/zip.rb').match(/\s+VERSION\s*=\s*'(.*)'/)[1]
  s.name = 'rubyzip'
  s.version = pkg_version
  s.author = ["Alan Harper", "Alexander Simonov"]
  s.email = ["alan@aussiegeek.net", "alex@simonov.me"]
  s.homepage = "http://github.com/simonoff/rubyzip"
  s.platform = Gem::Platform::RUBY
  s.summary = "rubyzip is a ruby module for reading and writing zip files"
  s.files = Dir.glob("{samples,lib}/**/*.rb") + %w{ README NEWS TODO Rakefile }
  s.require_path = 'lib'
  s.required_ruby_version = '>= 1.8.7'
end
