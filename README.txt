= rubyzip =

rubyzip is a ruby library for reading and writing zip (pkzip format)
files, with the restriction that only uncompressed and deflated zip
entries are supported. All this library does is handling of the zip
file format. the actual compression/decompression is handled by
zlib. zlib is accessible from ruby thanks to ruby/zlib (see resources)

To run the unit tests you need to have rubyunit installed.

= Resources =

zlib http://www.gzip.org/zlib/
ruby-zlib: http://www.blue.sky.or.jp/atelier/#ruby-zlib


= Ruby/zlib =

This library requires ruby/zlib version 0.5.0 or newer.


= LICENSE =

rubyzip is distributed under the same license as ruby. See
http://www.ruby-lang.org/en/LICENSE.txt

= AUTHOR =

Thomas Sondergaard thomass@deltadata.dk
