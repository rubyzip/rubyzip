require 'zip'

# This is a simple example which uses rubyzip to
# recursively generate a zip file from the contents of
# a specified directory. The directory itself is not
# included in the archive, rather just its contents.
#
# Usage:
#   directoryToZip = "/tmp/input"
#   output_file = "/tmp/out.zip"
#   zf = ZipFileGenerator.new(directory_to_zip, output_file)
#   zf.write()
class ZipFileGenerator

  # Initialize with the directory to zip and the location of the output archive.
  def initialize(input_dir, output_file)
    @input_dir = input_dir
    @output_file = output_file
  end

  # Zip the input directory.
  def write
    entries = Dir.entries(@inputDir)
    entries.delete('.')
    entries.delete('..')
    io = Zip::File.open(@outputFile, Zip::File::CREATE)

    write_entries(entries, '', io)
    io.close
  end

  # A helper method to make the recursion work.

  private

  def write_entries(entries, path, io)
    entries.each do |e|
      zipFilePath = path == '' ? e : File.join(path, e)
      diskFilePath = File.join(@inputDir, zipFilePath)
      puts 'Deflating ' + diskFilePath
      if  File.directory?(diskFilePath)
        io.mkdir(zipFilePath)
        subdir = Dir.entries(diskFilePath)
        subdir.delete('.')
        subdir.delete('..')
        write_entries(subdir, zipFilePath, io)
      else
        io.get_output_stream(zipFilePath) { |f| f.puts(File.open(diskFilePath, 'rb').read) }
      end
    end
  end
end
