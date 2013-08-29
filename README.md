# rubyzip
[![Build Status](https://secure.travis-ci.org/rubyzip/rubyzip.png)](http://travis-ci.org/rubyzip/rubyzip)
[![Code Climate](https://codeclimate.com/github/rubyzip/rubyzip.png)](https://codeclimate.com/github/rubyzip/rubyzip)
[![Coverage Status](https://coveralls.io/repos/rubyzip/rubyzip/badge.png?branch=master)](https://coveralls.io/r/rubyzip/rubyzip?branch=master)

rubyzip is a ruby library for reading and writing zip files.

## Important note

Rubyzip interface changed!!! No need to do `require "zip/zip"` and `Zip` prefix in class names removed.

## Installation
rubyzip is available on RubyGems, so:

```
gem install rubyzip
```

Or in your Gemfile:

```ruby
gem 'rubyzip'
```

## Usage

### Basic zip archive creation

```ruby
require 'rubygems'
require 'zip'

folder = "Users/me/Desktop/stuff_to_zip"
input_filenames = ['image.jpg', 'description.txt', 'stats.csv']

zipfile_name = "/Users/me/Desktop/archive.zip"

Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
  input_filenames.each do |filename|
    # Two arguments:
    # - The name of the file as it will appear in the archive
    # - The original file, including the path to find it
    zipfile.add(filename, folder + '/' + filename)
  end
end
```

### Zipping a directory recursively

```ruby
require 'rubygems'
require 'zip'

directory = '/Users/me/Desktop/directory_to_zip/'
zipfile_name = '/Users/me/Desktop/recursive_directory.zip'

Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
	Dir[File.join(directory, '**', '**')].each do |file|
	  zipfile.add(file.sub(directory, ''), file)
	end
end
```

## Known issues

### Modify docx file with rubyzip

Use `write_buffer` instead `open`. Thanks to @jondruse

```ruby
buffer = Zip::OutputStream.write_buffer do |out|
  @zip_file.entries.each do |e|
    unless [DOCUMENT_FILE_PATH, RELS_FILE_PATH].include?(e.name)
      out.put_next_entry(e.name)
      out.write e.get_input_stream.read
     end
  end

  out.put_next_entry(DOCUMENT_FILE_PATH)
  out.write xml_doc.to_xml(:indent => 0).gsub("\n","")

  out.put_next_entry(RELS_FILE_PATH)
  out.write rels.to_xml(:indent => 0).gsub("\n","")
end

File.open(new_path, "w") {|f| f.write(buffer.string) }
```

## Further Documentation

There is more than one way to access or create a zip archive with
rubyzip. The basic API is modeled after the classes in
java.util.zip from the Java SDK. This means there are classes such
as Zip::InputStream, Zip::OutputStream and
Zip::File. Zip::InputStream provides a basic interface for
iterating through the entries in a zip archive and reading from the
entries in the same way as from a regular File or IO
object. OutputStream is the corresponding basic output
facility. Zip::File provides a mean for accessing the archives
central directory and provides means for accessing any entry without
having to iterate through the archive. Unlike Java's
java.util.zip.ZipFile rubyzip's Zip::File is mutable, which means
it can be used to change zip files as well.

Another way to access a zip archive with rubyzip is to use rubyzip's
Zip::FileSystem API. Using this API files can be read from and
written to the archive in much the same manner as ruby's builtin
classes allows files to be read from and written to the file system.

For details about the specific behaviour of classes and methods refer
to the test suite. Finally you can generate the rdoc documentation or
visit http://rubyzip.sourceforge.net.


## Configuration

By default, rubyzip will not overwrite files if they already exist inside of the extracted path.  To change this behavior, you may specify a configuration option like so:

```ruby
Zip.on_exists_proc = true
```

If you're using rubyzip with rails, consider placing this snippet of code in an initializer file such as `config/initializers/rubyzip.rb`

Additionally, if you want to configure rubyzip to overwrite existing files while creating a .zip file, you can do so with the following:

```ruby
Zip.continue_on_exists_proc = true
```

If you want to store non english names and want to open properly file on Windows(pre 7) you need to set next option:

```ruby
Zip.unicode_names = true
```

All settings in same time

```ruby
  Zip.setup do |c|
    c.on_exists_proc = true
    c.continue_on_exists_proc = true
    c.unicode_names = true
  end
```

## Developing

To run tests you need run next commands:

```
bundle install
rake
```

## Website and Project Home

http://github.com/rubyzip/rubyzip

http://rdoc.info/github/rubyzip/rubyzip/master/frames

## Authors

Alexander Simonov ( alex at simonov.me)

Alan Harper ( alan at aussiegeek.net)

Thomas Sondergaard (thomas at sondergaard.cc)

Technorama Ltd. (oss-ruby-zip at technorama.net)

extra-field support contributed by Tatsuki Sugiura (sugi at nemui.org)

## License

rubyzip is distributed under the same license as ruby. See
http://www.ruby-lang.org/en/LICENSE.txt
