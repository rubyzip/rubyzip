#!/usr/bin/env ruby

require 'singleton'
require 'tempfile'
require 'zlib'

module Enumerable
  def inject(n = 0)
    each { |value| n = yield(n, value) }
    n
  end
end

module Zip
  
  # Implements many of the convenience methods of IO
  # such as gets, getc, readline and readlines 
  # depends on: inputFinished?, produceInput and read
  module AbstractInputStream
    include Enumerable
    
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
  

  #relies on <<
  module AbstractOutputStream
    def write(data)
      self << data
      data.to_s.length
    end


    def print(*params)
      self << params.to_s << $\.to_s
    end

    def printf(aFormatString, *params)
      self << sprintf(aFormatString, *params)
    end

    def putc(anObject)
      self << case anObject
	      when Fixnum then anObject.chr
	      when String then anObject
	      else raise TypeError, "putc: Only Fixnum and String supported"
	      end
      anObject
    end
    
    def puts(*params)
      params << "\n" if params.empty?
      params.flatten.each {
	|element|
	val = element.to_s
	self << val
	self << "\n" unless val[-1,1] == "\n"
      }
    end

  end
  
  
  class ZipInputStream 
    include AbstractInputStream
    
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
      
      @currentEntry = ZipEntry.readLocalEntry(@archiveIO)
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
    CHUNK_SIZE=32768
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
      return valueWhenFinished if @outputBuffer.length==0 && inputFinished?
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

    private
    def valueWhenFinished   # mimic behaviour of ruby File object.
      return nil if @hasReturnedEmptyString
      @hasReturnedEmptyString=true
      return ""
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
    
    attr_accessor  :comment, :compressedSize, :crc, :extra, :compressionMethod, 
      :name, :size, :localHeaderOffset
    
    def initialize(name = "", comment = "", extra = "", compressedSize = 0,   
		   crc = 0, compressionMethod = ZipEntry::DEFLATED, size = 0)
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
      LOCAL_ENTRY_STATIC_HEADER_LENGTH + (@name ?  @name.size : 0) + (@extra ? @extra.size : 0)
    end

    def cdirHeaderSize
      CDIR_ENTRY_STATIC_HEADER_LENGTH  + (@name ?  @name.size : 0) + 
	(@extra ? @extra.size : 0) + (@comment ? @comment.size : 0)
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
    public
    
    LOCAL_ENTRY_SIGNATURE = 0x04034b50
    LOCAL_ENTRY_STATIC_HEADER_LENGTH = 30
    
    def readLocalEntry(io)
      @localHeaderOffset = io.tell
      staticSizedFieldsBuf = io.read(LOCAL_ENTRY_STATIC_HEADER_LENGTH)
      unless (staticSizedFieldsBuf.size==LOCAL_ENTRY_STATIC_HEADER_LENGTH)
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
    
    def ZipEntry.readLocalEntry(io)
      entry = new()
      entry.readLocalEntry(io)
      return entry
    rescue ZipError
      return nil
    end
  
    def writeLocalEntry(io)
      @localHeaderOffset = io.tell
      
      io << 
	[LOCAL_ENTRY_SIGNATURE    ,
	@version                  ,
	@gpFlags                  ,
	@compressionMethod        ,
	@lastModTime              ,
	@lastModDate              ,
	@crc                      ,
	@compressedSize           ,
	@size                     ,
	@name ? @name.length   : 0,
	@extra? @extra.length : 0 ].pack('VvvvvvVVVvv')
      io << @name
      io << @extra
    end
    
    CENTRAL_DIRECTORY_ENTRY_SIGNATURE = 0x02014b50
    CDIR_ENTRY_STATIC_HEADER_LENGTH = 46
    
    def readCDirEntry(io)
      staticSizedFieldsBuf = io.read(CDIR_ENTRY_STATIC_HEADER_LENGTH)
      unless (staticSizedFieldsBuf.size == CDIR_ENTRY_STATIC_HEADER_LENGTH)
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
    
    def ZipEntry.readCDirEntry(io)
      entry = new()
      entry.readCDirEntry(io)
      return entry
    rescue ZipError
      return nil
    end


    def writeCDirEntry(io)
      io << 
	[CENTRAL_DIRECTORY_ENTRY_SIGNATURE,
	@version                          ,
	@versionNeededToExtract           ,
	@gpFlags                          ,
	@compressionMethod                ,
	@lastModTime                      ,
	@lastModDate                      ,
	@crc                              ,
	@compressedSize                   ,
	@size                             ,
	@name  ?  @name.length  : 0       ,
	@extra ? @extra.length : 0        ,
	@comment ? comment.length : 0     ,
	0                                 , # disk number start
	@internalFileAttributes           ,
	@externalFileAttributes           ,
	@localHeaderOffset                ,
	@name                             ,
	@extra                            ,
	@comment                          ].pack('VvvvvvvVVVvvvvvVV')

      io << @name
      io << @extra
      io << @comment
    end
    
    def == (other)
      return false unless other.kind_of?(ZipEntry)

      # Compares contents of local entry and exposed fields
      (@compressionMethod == other.compressionMethod &&
       @crc               == other.crc		     &&
       @compressedSize    == other.compressedSize    &&
       @size              == other.size	             &&
       @name              == other.name	             &&
       @extra             == other.extra)
    end

    def getInputStreamForZipFile(zipFileName)
      zis = ZipInputStream.new(zipFileName, localHeaderOffset)
    end
  end


  class ZipOutputStream
    include AbstractOutputStream

    attr_accessor :comment

    def initialize(fileName)
      @fileName = fileName
      @outputStream = File.new(@fileName, "wb")
      @entries = []
      @compressor = NullCompressor.instance
    end

    def ZipOutputStream.open(fileName)
      return new(fileName) unless block_given?
      zos = new(fileName)
      yield zos
    ensure
      zos.close if zos
    end

    def close
      return if @closed
      finalizeCurrentEntry
      updateLocalHeaders
      writeCentralDirectory
      @outputStream.close
      @closed = true
    end

    def putNextEntry(entry, level = Zlib::DEFAULT_COMPRESSION)
      raise ZipError, "zip stream is closed" if @closed
      newEntry = entry.kind_of?(ZipEntry) ? entry : ZipEntry.new(entry.to_s)
      initNextEntry(newEntry)
      @currentEntry=newEntry
    end

    private
    def finalizeCurrentEntry
      return unless @currentEntry
      finish
      @currentEntry.compressedSize = @outputStream.tell - @currentEntry.localHeaderOffset - 
	@currentEntry.localHeaderSize
      @currentEntry.size = @compressor.size
      @currentEntry.crc = @compressor.crc
      @currentEntry = nil
      @compressor = NullCompressor.instance
    end
    
    def initNextEntry(entry, level = Zlib::DEFAULT_COMPRESSION)
      finalizeCurrentEntry
      @entries << entry
      entry.writeLocalEntry(@outputStream)
      @compressor = getCompressor(entry, level)
    end

    def getCompressor(entry, level)
      case entry.compressionMethod
	when ZipEntry::DEFLATED then Deflater.new(@outputStream, level)
	when ZipEntry::STORED   then PassThruCompressor.new(@outputStream)
      else raise ZipError, "Invalid compression method: '#{entry.compressionMethod}'"
      end
    end

    def updateLocalHeaders
      pos = @outputStream.tell
      @entries.each {
	|entry|
	@outputStream.pos = entry.localHeaderOffset
	entry.writeLocalEntry(@outputStream)
      }
      @outputStream.pos = pos
    end

    def writeCentralDirectory
      cdir = ZipCentralDirectory.new(@entries, @comment)
      cdir.writeToStream(@outputStream)
    end

    protected

    def finish
      @compressor.finish
    end

    public
    def << (data)
      @compressor << data
    end
  end
  
  
  class Compressor
    def finish
    end
  end
  
  class PassThruCompressor < Compressor
    def initialize(outputStream)
      @outputStream = outputStream
      @crc = Zlib::crc32
      @size = 0
    end
    
    def << (data)
      val = data.to_s
      @crc = Zlib::crc32(val, @crc)
      @size += val.size
      @outputStream << val
    end

    attr_reader :size, :crc
  end

  class NullCompressor < Compressor
    include Singleton

    def << (data)
      raise IOError, "closed stream"
    end

    attr_reader :size, :compressedSize
  end

  class Deflater < Compressor
    def initialize(outputStream, level = Zlib::DEFAULT_COMPRESSION)
      @outputStream = outputStream
      @zlibDeflater = Zlib::Deflate.new(level, -Zlib::Deflate::MAX_WBITS)
      @size = 0
      @crc = Zlib::crc32
    end
    
    def << (data)
      val = data.to_s
      @crc = Zlib::crc32(val, @crc)
      @size += val.size
      @outputStream << @zlibDeflater.deflate(data)
    end

    def finish
      until @zlibDeflater.finished?
	@outputStream << @zlibDeflater.finish
      end
    end

    attr_reader :size, :crc
  end
  
  class ZipCentralDirectory
    include Enumerable
    
    END_OF_CENTRAL_DIRECTORY_SIGNATURE = 0x06054b50
    MAX_END_OF_CENTRAL_DIRECTORY_STRUCTURE_SIZE = 65536 + 18
    STATIC_EOCD_SIZE = 22

    attr_reader :size, :comment, :entries
    
    def initialize(entries = [], comment = "")
      @entries = entries
      @comment = comment
    end

    def writeToStream(io)
      offset = io.tell
      @entries.each { |entry| entry.writeCDirEntry(io) }
      writeEOCD(io, offset)
    end

    def writeEOCD(io, offset)
      io <<
	[END_OF_CENTRAL_DIRECTORY_SIGNATURE,
        0                                  , # @numberOfThisDisk
	0                                  , # @numberOfDiskWithStartOfCDir
	@entries? @entries.size : 0        ,
	@entries? @entries.size : 0        ,
	cdirSize                           ,
	offset                             ,
	@comment ? @comment.length : 0     ].pack('VvvvvVVv')
      io << @comment
    end
    private :writeEOCD

    def cdirSize
      # does not include eocd
      @entries.inject { |value, entry| entry.cdirHeaderSize + value }
    end
    private :cdirSize

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
	@entries << ZipEntry.readCDirEntry(io)
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

    def == (other)
      return false unless other.kind_of?(ZipCentralDirectory)
      @entries == other.entries && comment == other.comment
    end
  end
  
  
  
  class ZipError < RuntimeError
  end
  
  class BasicZipFile < ZipCentralDirectory
    attr_reader :name
    
    def initialize(name)
      @name=name
      File.open(name) {
	|file|
	readFromStream(file)
      }
    end
    
    def BasicZipFile.foreach(aZipFileName, &block)
      zipFile = BasicZipFile.new(aZipFileName)
      zipFile.each &block
    end
    
    def getInputStream(entry)
      selectedEntry = getEntry(entry)
      zis = selectedEntry.getInputStreamForZipFile(name)
      zis.getNextEntry
      return zis
    end

    protected
    def getEntry(entry)
      selectedEntry = @entries.detect { |e| e.name == entry.to_s }
      unless selectedEntry
      raise ZipError, 
	"No matching entry found in zip file '#{@name}' for '#{entry}'"
      end
      return selectedEntry
    end
  end



  class ZipFile < BasicZipFile
    CREATE = 1
    
    def initialize(fileName, create = nil)
      @name = fileName
      if (File.exists?(fileName))
	super(fileName)
	fixEntries
      elsif (create == ZipFile::CREATE)
	@entries = []
      else
	raise ZipError, "File #{fileName} not found"
      end
    end
    
    def ZipFile.open(fileName, create = nil)
      zf = ZipFile.new(fileName, create)
      if block_given?
	begin
	  yield zf
	ensure
	  zf.close
	end
      else
	zf
      end
    end
    
    def add(entry, srcPath) 
      zipStreamable = ZipStreamableFile.new(entry, srcPath)
      @entries << zipStreamable
    end
    
    def remove(entry)
      @entries.delete(getEntry(entry))
    end
    
    def rename(entry, newName, continueOnExistsProc = proc { false })
      foundEntry = getEntry(entry)
      if getEntry(newName) 
	if continueOnExistsProc.call
	  remove getEntry(newName)
	else
	  raise ZipError, "Cannot rename to #{newName}. An entry with that name exists"
	end
      end
      foundEntry.name=newName
    end
    
    def replace(entry, srcPath)
      checkFile(srcPath)
      add(remove(entry), srcPath)
    end
    
    def getInputStream(entry, &aProc)
      getEntry(entry).getInputStream &aProc
    end
    
    def extract(entry, destPath, onExistsProc = proc { false })
      foundEntry = getEntry(entry)
      writeFile(destPath, onExistsProc) { 
	|os|
	foundEntry.getInputStream { |is| os << is.read }
      }
    end
    
    def commit
      onSuccessReplace(name) {
	|tmpFile|
	ZipOutputStream.open(tmpFile) {
	  |zos|
	  @entries.each { |e| e.writeToZipOutputStream(zos) }
	}
	true
      }
    end
    
    def close
      commit
    end
    
    private
    
    def writeFile(destPath, continueOnExistsProc = proc { false }, &writeFileProc)
      if File.exists?(destPath) && ! continueOnExistsProc.call
	raise ZipError,
	  "Destination '#{destPath}' already exists"
      end
      File.open(destPath, "wb") &writeFileProc
    end
    
    def checkFile(path)
      unless File.readable? path
	raise ZipError, "'#{path}' does not exist or cannot be opened reading"
      end
    end
    
    def onSuccessReplace(aFilename)
      tmpfile = getTempfile
      tmpFilename = tmpfile.path
      tmpfile.close
      if yield tmpFilename
	File.move(tmpFilename, name)
      end
    end
    
    def fixEntries
      @entries.map! { |e| ZipStreamableZipEntry.new(e) }
    end
    
    def getTempfile
      Tempfile.new(File.basename(name), File.dirname(name)).binmode
    end
    
  end
  
  
  class ZipStreamable < ZipEntry
    def writeToZipOutputStream(aZipOutputStream)
      raise "implement 'writeToZipOutputStream' in subclass"
    end
    
    def getInputStream
      raise "implement 'getInputStream' in subclass"
    end
    
    def ==(other)
      raise "implement '==' in subclass"
    end
  end
  
  class ZipStreamableFile < ZipStreamable
  end
  
  class ZipStreamableZipEntry < ZipStreamable
    def initialize(entry)
    end
  end
  
end # Zip namespace module




# Copyright (C) 2002 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
