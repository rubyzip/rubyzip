#!/usr/bin/env ruby

require 'singleton'
require 'zlib'

# Implements many of the convenience methods of IO
# such as gets, getc, readline and readlines 
module PseudoIO
  def readlines(aSepString = $/)
    retVal = []
    each_line(aSepString) { |line| retVal << line }
    return retVal
  end

  def gets(aSepString=$/)
    @outputBuffer="" unless @outputBuffer
    return read if aSepString == nil
    aSepString="#{$/}#{$/}" if aSepString == ""

    bufferIndex=0
    while ((matchIndex = @outputBuffer.index(aSepString, bufferIndex)) == nil)
      bufferIndex=@outputBuffer.length
      if inputFinished?
	return @outputBuffer.length==0 ? nil : flush 
      end
      @outputBuffer << produceInput
    end
    sepIndex=matchIndex + aSepString.length
    return @outputBuffer.slice!(0...sepIndex)
  end
  
  def flush
    retVal=@outputBuffer
    @outputBuffer=""
    return retVal
  end

  def readline(aSepString = $/)
    retVal = gets(aSepString)
    raise EOFError if retVal == nil
    return retVal
  end

  def each_line(aSepString = $/)
    while true
      yield readline
    end
    rescue EOFError
  end

  alias_method :each, :each_line
end



class ZipInputStream 
  include PseudoIO

  def initialize(filename)
    @archiveIO = File.open(filename, "rb")
    @decompressor = NullDecompressor.instance
  end

  def close
    puts "IMPLEMENT ME: ZipInputStream::close"
  end
  
  def ZipInputStream.open(filename)
    return new(filename) unless block_given?

    zio = new(filename)
    yield zio
    zio.close
  end

  def getNextEntry
    @archiveIO.seek(@currentEntry.nextHeaderOffset, 
		    IO::SEEK_SET) if @currentEntry

    @currentEntry = ZipLocalEntry.readFromStream(@archiveIO)
    if (@currentEntry == nil) 
      @decompressor = NullDecompressor.instance
    elsif @currentEntry.compressionMethod == ZipEntry::STORED
      @decompressor = PassThruDecompressor.new(@archiveIO, 
					       @currentEntry.size)
    elsif @currentEntry.compressionMethod == ZipEntry::DEFLATED
      @decompressor = Inflater.new(@archiveIO)
    else
      raise "Unsupported compression method #{@currentEntry.compressionMethod}"
    end
    flush
    return @currentEntry
  end

  def read(numberOfBytes = nil)
    @decompressor.read(numberOfBytes)
  end
  protected
  def produceInput
    @decompressor.produceInput
  end

  def inputFinished?
    @decompressor.inputFinished?
  end
end



class Decompressor
  CHUNK_SIZE=8192
  def initialize(inputStream)
    @inputStream=inputStream
  end
end

class Inflater < Decompressor
  def initialize(inputStream)
    super
    @zlibInflater = Inflate.new(-Inflate::MAX_WBITS)
    @outputBuffer=""
  end

  def read(numberOfBytes = nil)
    readEverything = (numberOfBytes == nil)
    while (readEverything || @outputBuffer.length < numberOfBytes)
      break if inputFinished?
      @outputBuffer << produceInput
    end
    return nil if @outputBuffer.length==0 && inputFinished?
    endIndex= numberOfBytes==nil ? @outputBuffer.length : numberOfBytes
    return @outputBuffer.slice!(0...endIndex)
  end

  def produceInput
    @zlibInflater.inflate(@inputStream.read(Decompressor::CHUNK_SIZE))
  end
  
  def inputFinished?
    @zlibInflater.finished?
  end
end

class PassThruDecompressor < Decompressor
  def initialize(inputStream, charsToRead)
    super inputStream
    @charsToRead = charsToRead
    @readSoFar = 0
    @isFirst=true
  end

  def read(numberOfBytes = nil)
    if inputFinished?
      isFirstVal=@isFirst
      @isFirst=false
      return "" if isFirstVal
      return nil
    end

    if (numberOfBytes == nil || @readSoFar+numberOfBytes > @charsToRead)
      numberOfBytes = @charsToRead-@readSoFar
    end
    @readSoFar += numberOfBytes
    @inputStream.read(numberOfBytes)
  end

  def produceInput
    read(Decompressor::CHUNK_SIZE)
  end
  
  def inputFinished?
    (@readSoFar >= @charsToRead)
  end
end

class NullDecompressor
  include Singleton
  def read(numberOfBytes = nil)
    nil
  end

  def produceInput
    nil
  end
  
  def inputFinished?
    true
  end
end



class ZipEntry
  STORED = 0
  DEFLATED = 8

  attr_reader :comment, :compressedSize, :crc, :extra, :compressionMethod, 
		 :name, :size, :localHeaderOffset

  def initialize(comment = nil, compressedSize = nil, crc = nil, extra = nil, 
		 compressionMethod = nil, name = nil, size = nil)
    @comment, @compressedSize, @crc, @extra, @compressionMethod, 
      @name, @size, @isDirectory = comment, compressedSize, crc, 
      extra, compressionMethod, name, size
  end

  def isDirectory
    return (%r{\/$} =~ @name) != nil
  end

  def localEntryOffset
    localHeaderOffset + localHeaderSize
  end

  def localHeaderSize
    30 + name.size + extra.size
  end

  def nextHeaderOffset
    localEntryOffset + self.compressedSize
  end

  protected

  def ZipEntry.readZipShort(io)
    io.read(2).unpack('v')[0]
  end
  
  def ZipEntry.readZipLong(io)
    io.read(4).unpack('V')[0]
  end

end



class ZipLocalEntry < ZipEntry
  LOCAL_ENTRY_SIGNATURE = 0x04034b50

  def readFromStream(io)
    unless (ZipEntry::readZipLong(io) == LOCAL_ENTRY_SIGNATURE)
      raise ZipError,
	"Zip local header magic '#{LOCAL_ENTRY_SIGNATURE} not found"
    end
    @localHeaderOffset = io. tell - 4
    @version           = ZipEntry::readZipShort(io)
    @gpFlags           = ZipEntry::readZipShort(io)
    @compressionMethod = ZipEntry::readZipShort(io)
    @lastModTime       = ZipEntry::readZipShort(io) 
    @lastModDate       = ZipEntry::readZipShort(io) 
    @crc               = ZipEntry::readZipLong(io) 
    @compressedSize    = ZipEntry::readZipLong(io)
    @size              = ZipEntry::readZipLong(io)
    nameLength         = ZipEntry::readZipShort(io)
    extraLength        = ZipEntry::readZipShort(io)
    @name              = io.read(nameLength)
    @extra             = io.read(extraLength)
  end

  def ZipLocalEntry.readFromStream(io)
    entry = new()
    entry.readFromStream(io)
    return entry
  rescue ZipError
    return nil
  end
end

class ZipCentralDirectoryEntry < ZipEntry
  CENTRAL_DIRECTORY_ENTRY_SIGNATURE = 0x02014b50

  def readFromStream(io)
    unless (ZipEntry::readZipLong(io) == CENTRAL_DIRECTORY_ENTRY_SIGNATURE)
      raise ZipError,
	"Zip central directory header magic '#{CENTRAL_DIRECTORY_ENTRY_SIGNATURE} not found"
    end
    @version                = ZipEntry::readZipShort(io)
    @versionNeededToExtract = ZipEntry::readZipShort(io)
    @gpFlags                = ZipEntry::readZipShort(io)
    @compressionMethod      = ZipEntry::readZipShort(io)
    @lastModTime            = ZipEntry::readZipShort(io) 
    @lastModDate            = ZipEntry::readZipShort(io) 
    @crc                    = ZipEntry::readZipLong(io) 
    @compressedSize         = ZipEntry::readZipLong(io)
    @size                   = ZipEntry::readZipLong(io)
    nameLength              = ZipEntry::readZipShort(io)
    extraLength             = ZipEntry::readZipShort(io)
    commentLength           = ZipEntry::readZipShort(io)
    diskNumberStart         = ZipEntry::readZipShort(io)
    @internalFileAttributes = ZipEntry::readZipShort(io)
    @externalFileAttributes = ZipEntry::readZipLong(io)
    @localHeaderOffset      = ZipEntry::readZipLong(io)
    @name                   = io.read(nameLength)
    @extra                  = io.read(extraLength)
    @comment                = io.read(commentLength)
  end

  def ZipCentralDirectoryEntry.readFromStream(io)
    entry = new()
    entry.readFromStream(io)
    return entry
  rescue ZipError
    return nil
  end
end



#        File header:

#          central file header signature   4 bytes  (0x02014b50)
#          version made by                 2 bytes
#          version needed to extract       2 bytes
#          general purpose bit flag        2 bytes
#          compression method              2 bytes
#          last mod file time              2 bytes
#          last mod file date              2 bytes
#          crc-32                          4 bytes
#          compressed size                 4 bytes
#          uncompressed size               4 bytes
#          file name length                2 bytes
#          extra field length              2 bytes
#          file comment length             2 bytes
#          disk number start               2 bytes
#          internal file attributes        2 bytes
#          external file attributes        4 bytes
#          relative offset of local header 4 bytes

#          file name (variable size)
#          extra field (variable size)
#          file comment (variable size)


#  end of central dir signature    4 bytes  (0x06054b50)
#          number of this disk             2 bytes
#          number of the disk with the
#          start of the central directory  2 bytes
#          total number of entries in the
#          central directory on this disk  2 bytes
#          total number of entries in
#          the central directory           2 bytes
#          size of the central directory   4 bytes
#          offset of start of central
#          directory with respect to
#          the starting disk number        4 bytes
#          .ZIP file comment length        2 bytes
#          .ZIP file comment       (variable size)



#        Digital signature:

#          header signature                4 bytes  (0x05054b50)
#          size of data                    2 bytes
#          signature data (variable size)


class ZipError < RuntimeError
end

class ZipFile
  include Enumerable

  attr_reader :name

  def initialize(name)
    @name=name
  end

  def ZipFile.foreach(aZipFileName, &block)
    zipFile = ZipFile.new(aZipFileName)
    zipFile.each &block
  end

  def each
  end

  def getInputStream(entry)
  end
end

