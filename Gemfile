# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# TODO: remove when JRuby 9.4.10.0 will be released and available on CI
# Ref: https://github.com/jruby/jruby/issues/7262
gem 'jar-dependencies', '0.4.1' if RUBY_PLATFORM.include?('java')
