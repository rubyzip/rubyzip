#!/usr/bin/env ruby

require 'zip'

# Relies on:
# * extract(src, dst)
module FileArchive
  RECURSIVE = true

  def extract(src, dst, recursive = RECURSIVE)
    selectedEntries = Glob.glob(entries, src, recursive)
    if (selectedEntries.size == 0)
      raise ZipNoSuchEntryError, "'#{src}' not found in archive #{self.to_s}"
    end
    createDstAsDirectory = (selectedEntries.size == 1)
    selectedEntries.each {
      |srcEntryFull, srcEntryName|
      extractEntry(srcEntryFull, dst)
    }
  end
end

