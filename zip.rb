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

  def initialize(filename, offset = 0)
    @archiveIO = File.open(filename, "rb")
    @archiveIO.seek(offset, IO::SEEK_SET)
    @decompressor = NullDecompressor.instance
  end

  def close
    @archiveIO.close
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
    @zlibInflater = Zlib::Inflate.new(-Zlib::Inflate::MAX_WBITS)
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

  # to be used with produceInput, not read (as read may still have more data cached)
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

  def to_s
    @name
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
  STATIC_HEADER_LENGTH = 30

  def readFromStream(io)
    @localHeaderOffset = io. tell
    staticSizedFieldsBuf = io.read(STATIC_HEADER_LENGTH)
    unless (staticSizedFieldsBuf.size==STATIC_HEADER_LENGTH)
      raise ZipError, "Premature end of file. Not enough data for zip entry local header"
    end
    
    localHeader       ,
    @version          ,
    @gpFlags          ,
    @compressionMethod,
    @lastModTime      ,
    @lastModDate      ,
    @crc              ,
    @compressedSize   ,
    @size             ,
    nameLength        ,
    extraLength       = staticSizedFieldsBuf.unpack('VvvvvvVVVvv') 
    
    unless (localHeader == LOCAL_ENTRY_SIGNATURE)
      raise ZipError, "Zip local header magic not found at location '#{localHeaderOffset}'"
    end

    @name              = io.read(nameLength)
    @extra             = io.read(extraLength)
    unless (@extra && @extra.length == extraLength)
      raise ZipError, "Truncated local zip entry header"
    end
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
  STATIC_HEADER_LENGTH = 46

  def readFromStream(io)
    staticSizedFieldsBuf = io.read(STATIC_HEADER_LENGTH)
    unless (staticSizedFieldsBuf.size == STATIC_HEADER_LENGTH)
      raise ZipError, "Premature end of file. Not enough data for zip cdir entry header"
    end
    
    cdirSignature          ,
    @version               ,
    @versionNeededToExtract,
    @gpFlags               ,
    @compressionMethod     ,
    @lastModTime           ,
    @lastModDate           ,
    @crc                   ,
    @compressedSize        ,
    @size                  ,
    nameLength             ,
    extraLength            ,
    commentLength          ,
    diskNumberStart        ,
    @internalFileAttributes,
    @externalFileAttributes,
    @localHeaderOffset     ,
    @name                  ,
    @extra                 ,
    @comment               = staticSizedFieldsBuf.unpack('VvvvvvvVVVvvvvvVV')

    unless (cdirSignature == CENTRAL_DIRECTORY_ENTRY_SIGNATURE)
      raise ZipError, "Zip local header magic not found at location '#{localHeaderOffset}'"
    end

    @name                  = io.read(nameLength)
    @extra                 = io.read(extraLength)
    @comment               = io.read(commentLength)
    unless (@comment && @comment.length == commentLength)
      raise ZipError, "Truncated cdir zip entry header"
    end

  end

  def ZipCentralDirectoryEntry.readFromStream(io)
    entry = new()
    entry.readFromStream(io)
    return entry
  rescue ZipError
    return nil
  end
end


class ZipCentralDirectory
  include Enumerable

  END_OF_CENTRAL_DIRECTORY_SIGNATURE = 0x06054b50
  MAX_END_OF_CENTRAL_DIRECTORY_STRUCTURE_SIZE = 65536 + 18

  attr_reader :size, :comment

  def readEOCD(io)
    buf = getEOCD(io)
    @numberOfThisDisk                     = ZipEntry::readZipShort(buf)
    @numberOfDiskWithStartOfCDir          = ZipEntry::readZipShort(buf)
    @totalNumberOfEntriesInCDirOnThisDisk = ZipEntry::readZipShort(buf)
    @size                                 = ZipEntry::readZipShort(buf)
    @sizeInBytes                          = ZipEntry::readZipLong(buf)
    @cdirOffset                           = ZipEntry::readZipLong(buf)
    commentLength                         = ZipEntry::readZipShort(buf)
    @comment                              = buf.read(commentLength)
    raise ZipError, "Zip consistency problem while reading eocd structure" unless buf.size == 0
  end

  def readCentralDirectoryEntries(io)
    begin
      io.seek(@cdirOffset, IO::SEEK_SET)
    rescue Errno::EINVAL
      raise ZipError, "Zip consistency problem while reading central directory entry"
    end
    @entries = []
    @size.times {
      @entries << ZipCentralDirectoryEntry.readFromStream(io)
    }
  end

  def readFromStream(io)
    readEOCD(io)
    readCentralDirectoryEntries(io)
  end

  def getEOCD(io)
    begin
      io.seek(-MAX_END_OF_CENTRAL_DIRECTORY_STRUCTURE_SIZE, IO::SEEK_END)
    rescue Errno::EINVAL
      io.seek(0, IO::SEEK_SET)
    end
    buf = io.read
    sigIndex = buf.rindex([END_OF_CENTRAL_DIRECTORY_SIGNATURE].pack('V'))
    raise ZipError, "Zip end of central directory signature not found" unless sigIndex
    buf=buf.slice!((sigIndex+4)...(buf.size))
    def buf.read(count)
      slice!(0, count)
    end
    return buf
  end

  def each(&proc)
    @entries.each &proc
  end

  def ZipCentralDirectory.readFromStream(io)
    cdir  = new
    cdir.readFromStream(io)
    return cdir
  rescue ZipError
    return nil
  end
end



class ZipError < RuntimeError
end

class ZipFile < ZipCentralDirectory
  attr_reader :name

  def initialize(name)
    @name=name
    File.open(name) {
      |file|
      readFromStream(file)
    }
  end

  def ZipFile.foreach(aZipFileName, &block)
    zipFile = ZipFile.new(aZipFileName)
    zipFile.each &block
  end

  def getInputStream(entry)
    selectedEntry = @entries.detect { |e| e.name == entry.to_s }
    raise ZipError, "No matching entry found in zip file '#{@name}' for '#{}'" unless selectedEntry
    zis = ZipInputStream.new(@name, selectedEntry.localHeaderOffset)
    zis.getNextEntry
    return zis
  end
end

