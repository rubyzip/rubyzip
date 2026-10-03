# frozen_string_literal: true

# Compares ways of finding the character-safe cut point for
# `AbstractInputStream#gets` when a limit is given:
#
# * current   - `AbstractInputStream#char_safe_cut_index` as it is in `lib/`.
# * each_char - `each_char` walked from the start of the buffer (the previous
#               implementation of `char_safe_cut_index`).
# * stringio  - `StringIO#gets(nil, limit)` and `StringIO#pos`.

require 'bundler/setup'
require 'zip'
require 'benchmark'
require 'stringio'

MAX_CHAR_BYTES = Zip::IOExtras::AbstractInputStream::MAX_CHAR_BYTES

# A stream stub that only provides what `char_safe_cut_index` needs.
class Stream
  include Zip::IOExtras::AbstractInputStream

  def initialize(buffer)
    @output_buffer = buffer
  end

  def cut_index(cut, encoding)
    char_safe_cut_index(cut, encoding)
  end
end

def each_char_cut_index(buffer, cut, encoding)
  window = buffer.byteslice(0, cut + MAX_CHAR_BYTES).force_encoding(encoding)
  window.each_char.reduce(0) do |pos, char|
    break pos if pos >= cut

    pos + char.bytesize
  end
end

def stringio_cut_index(buffer, cut, encoding)
  window = buffer.byteslice(0, cut + MAX_CHAR_BYTES)
  reader = StringIO.new(window.force_encoding(encoding))
  reader.gets(nil, cut)
  reader.pos
end

# Text with a mix of single and multi-byte characters for each encoding, so
# that most limits land in the middle of a character.
SAMPLES = {
  Encoding::UTF_8        => 'abc éèà € 日本語 👍 ',
  Encoding::UTF_16LE     => 'abc éèà € 日本語 👍 ',
  Encoding::UTF_32LE     => 'abc éèà € 日本語 👍 ',
  Encoding::SHIFT_JIS    => 'abc 日本語 ひらがな ',
  Encoding::EUC_JP       => 'abc 日本語 ひらがな ',
  Encoding::GBK          => 'abc 中文字符 ',
  Encoding::ISO_8859_1   => 'abc éèà ',
  Encoding::WINDOWS_1252 => 'abc éèà € '
}.freeze

BUFFER_SIZE = 4 * 1024 * 1024
CUTS = [0, 100, 10_000, 1_000_000].freeze
ITERATIONS = 200

def build_buffer(text, encoding)
  encoded = text.encode(encoding).b
  (encoded * ((BUFFER_SIZE / encoded.bytesize) + 1)).byteslice(0, BUFFER_SIZE)
end

def time(&block)
  GC.start
  Benchmark.realtime { ITERATIONS.times(&block) } / ITERATIONS * 1_000_000
end

puts "Ruby #{RUBY_VERSION} (#{RUBY_ENGINE}), #{ITERATIONS} iterations, " \
     "#{BUFFER_SIZE / 1024 / 1024} MiB buffer, microseconds per call"
puts 'encoding        cut_index      current    each_char     stringio'

SAMPLES.each do |encoding, text|
  buffer = build_buffer(text, encoding)
  stream = Stream.new(buffer)

  CUTS.each do |base|
    # Nudge the cut so it is not always on a boundary.
    cut = base + 1

    results = [
      stream.cut_index(cut, encoding),
      each_char_cut_index(buffer, cut, encoding),
      stringio_cut_index(buffer, cut, encoding)
    ]
    warn "MISMATCH #{encoding} #{cut}: #{results.inspect}" unless results.uniq.size == 1

    current   = time { stream.cut_index(cut, encoding) }
    each_char = time { each_char_cut_index(buffer, cut, encoding) }
    stringio  = time { stringio_cut_index(buffer, cut, encoding) }

    puts format('%<enc>-14s %<cut>10d %<cur>12.2f %<ec>12.2f %<sio>12.2f',
                enc: encoding, cut: cut, cur: current, ec: each_char, sio: stringio)
  end
end
