PKG_VERSION = File.read('lib/zip/zip.rb').match(/\s+VERSION\s*=\s*'(.*)'/)[1]

spec = Gem::Specification.new do |s|
  s.name = 'mezza-rubyzip'
  s.version = PKG_VERSION
  s.authors = ["Alan Harper", "Merul Patel"]
  s.email = ["alan@aussiegeek.net", "merul.patel@gmail.com"]
  s.homepage = "http://github.com/mezza/rubyzip"
  s.platform = Gem::Platform::RUBY
  s.summary = "rubyzip is a ruby module for reading and writing zip files"
  s.files = Dir.glob("{samples,lib}/**/*.rb") + %w{ README NEWS TODO Rakefile }
  s.require_path = 'lib'
  s.required_ruby_version = '>= 1.8.6'
end