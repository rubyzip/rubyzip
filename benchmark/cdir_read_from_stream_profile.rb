# frozen_string_literal: true

require 'bundler/setup'
require 'zip'
require 'stackprof'

DATA_DIR = File.expand_path('../test/data', __dir__)

zip_file = File.open(File.join(DATA_DIR, '100000-files.zip'), 'rb')
cdir = Zip::CentralDirectory.new

profile = StackProf.run(mode: :wall) do
  cdir.read_from_stream(zip_file)
end

zip_file.close

result = StackProf::Report.new(profile)
puts
result.print_text
puts "\n\n\n"
result.print_method(/Zip::CentralDirectory#read_from_stream/)
