# frozen_string_literal: true

require 'simplecov-lcov'

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.output_directory = 'coverage'
  c.lcov_file_name = 'lcov.info'
  c.report_with_single_file = true
  c.single_report_path = 'coverage/lcov.info'
end

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
)

SimpleCov.start do
  enable_coverage :branch
  add_filter ['/test/', '/samples/']
end
