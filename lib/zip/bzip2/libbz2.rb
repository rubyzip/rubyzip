# This file is copied from:
#
# https://github.com/philr/bzip2-ffi/raw/master/lib/bzip2/ffi/libbz2.rb
#

# Copyright (c) 2015-2016 Philip Ross
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'ffi'

module Zip
  module Bzip2
    # FFI bindings for the libbz2 low-level interface.
    #
    # See bzlib.h and http://bzip.org/docs.html.
    #
    # @private
    module Libbz2 #:nodoc:
      extend ::FFI::Library

      ffi_lib ['bz2', 'libbz2.so.1', 'libbz2.dll']

      BZ_RUN    = 0
      BZ_FLUSH  = 1
      BZ_FINISH = 2

      BZ_OK               =  0
      BZ_RUN_OK           =  1
      BZ_FLUSH_OK         =  2
      BZ_FINISH_OK        =  3
      BZ_STREAM_END       =  4
      BZ_SEQUENCE_ERROR   = -1
      BZ_PARAM_ERROR      = -2
      BZ_MEM_ERROR        = -3
      BZ_DATA_ERROR       = -4
      BZ_DATA_ERROR_MAGIC = -5
      BZ_CONFIG_ERROR     = -9

      # void *(*bzalloc)(void *,int,int);
      callback :bzalloc, [:pointer, :int, :int], :pointer

      # void (*bzfree)(void *,void *);
      callback :bzfree, [:pointer, :pointer], :void

      # typedef struct { ... } bz_stream;
      class BzStream < ::FFI::Struct #:nodoc:
        layout :next_in,       :pointer,
               :avail_in,      :uint,
               :total_in_lo32, :uint,
               :total_in_hi32, :uint,

               :next_out,       :pointer,
               :avail_out,      :uint,
               :total_out_lo32, :uint,
               :total_out_hi32, :uint,

               :state,          :pointer,

               :bzalloc,        :bzalloc,
               :bzfree,         :bzfree,
               :opaque,         :pointer
      end

      # int BZ2_bzCompressInt(bz_stream* strm, int blockSize100k, int verbosity, int workFactor);
      attach_function :BZ2_bzCompressInit, [BzStream.by_ref, :int, :int, :int], :int

      # int BZ2_bzCompress (bz_stream* strm, int action);
      attach_function :BZ2_bzCompress, [BzStream.by_ref, :int], :int

      # int BZ2_bzCompressEnd (bz_stream* strm);
      attach_function :BZ2_bzCompressEnd, [BzStream.by_ref], :int

      # int BZ2_bzDecompressInit (bz_stream *strm, int verbosity, int small);
      attach_function :BZ2_bzDecompressInit, [BzStream.by_ref, :int, :int], :int

      # int BZ2_bzDecompress (bz_stream* strm);
      attach_function :BZ2_bzDecompress, [BzStream.by_ref], :int

      # int BZ2_bzDecompressEnd (bz_stream *strm);
      attach_function :BZ2_bzDecompressEnd, [BzStream.by_ref], :int
    end
  end
end
