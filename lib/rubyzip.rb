require 'delegate'
require 'singleton'
require 'tempfile'
require 'fileutils'
require 'stringio'
require 'zlib'
require 'rubyzip/dos_time'
require 'rubyzip/ioextras'
require 'rbconfig'
require 'rubyzip/entry'
require 'rubyzip/extra_field'
require 'rubyzip/entry_set'
require 'rubyzip/central_directory'
require 'rubyzip/file'
require 'rubyzip/input_stream'
require 'rubyzip/output_stream'
require 'rubyzip/decompressor'
require 'rubyzip/compressor'
require 'rubyzip/null_decompressor'
require 'rubyzip/null_compressor'
require 'rubyzip/null_input_stream'
require 'rubyzip/pass_thru_compressor'
require 'rubyzip/pass_thru_decompressor'
require 'rubyzip/inflater'
require 'rubyzip/deflater'
require 'rubyzip/streamable_stream'
require 'rubyzip/streamable_directory'
require 'rubyzip/constants'
require 'rubyzip/errors'
if defined? JRUBY_VERSION
  require 'jruby'
  JRuby.objectspace = true
end

module RubyZip
  extend self
  attr_accessor :unicode_names, :on_exists_proc, :continue_on_exists_proc, :sort_entries, :default_compression, :write_zip64_support

  def reset!
    @_ran_once = false
    @unicode_names = false
    @on_exists_proc = false
    @continue_on_exists_proc = false
    @sort_entries = false
    @default_compression = ::Zlib::DEFAULT_COMPRESSION
    @write_zip64_support = false
  end

  def setup
    yield self unless @_ran_once
    @_ran_once = true
  end

  reset!
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
