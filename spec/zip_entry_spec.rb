require 'spec_helper'

describe ZipEntry do
  describe "read local entry HeaderOfFirstTestZipEntry" do
  	before do
	  @file = File.open(TestZipFile::TEST_ZIP3.zip_name, "rb")
	  @entry = ZipEntry.read_local_entry(@file)
	end

	it "should set compression method to deflated" do
	  @entry.compression_method.should == ZipEntry::DEFLATED
	end

	it "should set entry name correctly" do
	  @entry.name.should == TestZipFile::TEST_ZIP3.entry_names[0]
	end

	it "should set entry size correctly" do
	  File.size(TestZipFile::TEST_ZIP3.entry_names[0]).should == @entry.size
	end

	it "should not be a directory" do
	  @entry.is_directory.should be_false
	end
  end

  describe "read dateTime" do
  	before do
	  @file = File.open("data/rubycode.zip","rb")
	  @entry = ZipEntry.read_local_entry(@file)
	end

	it "should set the entry name" do
	  @entry.name.should == "zippedruby1.rb"
	end

	it "should set the time" do
	  @entry.time.should == Time.at(1019261638)
	end
  end

  it "should read local entry from non zipfile" do
  	@file = File.open("data/file2.txt")
  	ZipEntry.read_local_entry(@file).should be_nil
  end

  it "should throw ZipError reading from truncated zip" do
    zipFragment=""
    File.open(TestZipFile::TEST_ZIP2.zip_name) { |f| zipFragment = f.read(12) } # local header is at least 30 bytes
    zipFragment.extend(IOizeString).reset
    entry = ZipEntry.new
    proc { entry.read_local_entry(zipFragment) }.should raise_error ZipError
  end

  it "should write entry" do
    entry = ZipEntry.new("file.zip", "entryName", "my little comment", 
			 "thisIsSomeExtraInformation", 100, 987654, 
			 ZipEntry::DEFLATED, 400)
    write_to_file("localEntryHeader.bin", "centralEntryHeader.bin",  entry)
    entryReadLocal, entryReadCentral = read_from_file("localEntryHeader.bin", "centralEntryHeader.bin")
    compare_local_entry_headers(entry, entryReadLocal)
    compare_c_dir_entry_headers(entry, entryReadCentral)
  end
  
  private
  def compare_local_entry_headers(entry1, entry2)
    entry1.compressed_size.should == entry2.compressed_size
    entry1.crc.should ==  entry2.crc
    entry1.extra.should == entry2.extra
    entry1.compression_method.should == entry2.compression_method
    entry1.name.should == entry2.name
    entry1.size.should ==  entry2.size
    entry1.localHeaderOffset.should == entry2.localHeaderOffset
  end

  def compare_c_dir_entry_headers(entry1, entry2)
    compare_local_entry_headers(entry1, entry2)
    entry1.comment.should == entry2.comment
  end

  def write_to_file(localFileName, centralFileName, entry)
    File.open(localFileName,   "wb") { |f| entry.write_local_entry(f) }
    File.open(centralFileName, "wb") { |f| entry.write_c_dir_entry(f)  }
  end

  def read_from_file(localFileName, centralFileName)
    localEntry = nil
    cdirEntry  = nil
    File.open(localFileName,   "rb") { |f| localEntry = ZipEntry.read_local_entry(f) }
    File.open(centralFileName, "rb") { |f| cdirEntry  = ZipEntry.read_c_dir_entry(f) }
    return [localEntry, cdirEntry]
  end
end

# Copyright (C) 2002-2005 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
