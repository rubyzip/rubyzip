spec = Gem::Specification.new do |s|
  s.name = 'rubyzip'
  s.version = "0.9.9"
  s.author = "Alan Harper"
  s.email = "alan@aussiegeek.net"
  s.homepage = "http://github.com/aussiegeek/rubyzip"
  s.platform = Gem::Platform::RUBY
  s.summary = "rubyzip is a ruby module for reading and writing zip files"
  s.files = Dir.glob("{samples,lib}/**/*.rb") + %w{ README.md NEWS TODO Rakefile }
  s.require_path = 'lib'
  s.required_ruby_version = '>= 1.8.7'
end
