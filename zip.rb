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
    return (/\/$/ =~ @name) != nil
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
	"Zip Local Header magic '#{LOCAL_ENTRY_SIGNATURE} not found"
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

#  class ZipCentralDirectoryEntry < ZipEntry
#    ZIP_CENTRAL_DIRECTORY_ENTRY_SIGNATURE = 0x02014b50
  
#    def readFromStream(io)
#    end
  
#    def ZipCentralDirectoryEntry.readFromStream(io)
#      entry = new()
#      entry.readFromStream(io)
#      return entry
#    rescue ZipError
#      return nil
#    end
#  end

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

