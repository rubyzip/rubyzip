= rubyzip =

rubyzip is a ruby library for reading and writing zip (pkzip format)
files, with the restriction that only uncompressed and deflated zip
entries are supported. All this library does is handling of the zip
file format. the actual compression/decompression is handled by zlib


= Resources =
zlib http://www.gzip.org/zlib/
ruby-zlib: http://www.blue.sky.or.jp/atelier/#ruby-zlib


= Ruby/zlib issue =

There is a problem with ruby/zlib version 0.4.0 and earlier concerning
wbits, that prevents rubyzip from working. The ruby wrapper does some
parameters checks of its own, and restrict the wbits parameter passed
to inflateInit2 from being negative. Apply the patch 'zlib.c.diff' to
zlib.c from ruby/zlib, then rebuild and install ruby/zlib to fix the
issue.

To apply the patch cd to ruby-zlib-0.4.0 and:

patch -p0 < RUBYZIP_PATH/zlib.c.diff

= Missing tests =

zip.rb is only 280 lines. Go through it and check for each line
whether there is a test for it!

= todo for release 0.2.0 =
Write ZipFile or ZipDir that reads the zip central directory
