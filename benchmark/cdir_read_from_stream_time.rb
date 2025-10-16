# frozen_string_literal: true

require 'bundler/setup'
require 'zip'
require 'benchmark'
require 'benchmark/memory'

DATA_DIR = File.expand_path('../test/data', __dir__)

zip_file1 = File.open(File.join(DATA_DIR, 'globTest.zip'), 'rb')
zip_file2 = File.open(File.join(DATA_DIR, '100000-files.zip'), 'rb')
cdir1 = Zip::CentralDirectory.new
cdir2 = Zip::CentralDirectory.new

Benchmark.bmbm do |x|
  x.report('8 entries') { cdir1.read_from_stream(zip_file1) }
  x.report('100,000 entries') { cdir2.read_from_stream(zip_file2) }
end

zip_file1.close
zip_file2.close
