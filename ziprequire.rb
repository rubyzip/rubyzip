#!/usr/bin/env ruby

require 'zip'

class ZipList
  def initialize(zipFileList)
      @zipFileList = zipFileList
  end

  def getInputStream(entry, &aProc)
    @zipFileList.each {
      |zfName|
      Zip::ZipFile.open(zfName) {
	|zf|
	begin
	  return zf.getInputStream(entry, &aProc) 
	rescue Zip::ZipNoSuchEntryError
	end
      }
    }
    raise Zip::ZipNoSuchEntryError,
      "No matching entry found in zip files '#{@zipFileList.join(', ')}' "+
      " for '#{entry}'"
  end
end


module Kernel
  alias :oldRequire :require

  def require(moduleName)
    zipRequire(moduleName) || oldRequire(moduleName)
  end

  def zipRequire(moduleName)
    return false if alreadyLoaded?(moduleName)
    getResource(ensureRbExtension(moduleName)) { 
      |zis| 
      eval(zis.read); $" << moduleName 
    }
    return true
  rescue Zip::ZipNoSuchEntryError => ex
    return false
  end

  def getResource(resourceName, &aProc)
    zl = ZipList.new($:.grep /\.zip$/)
    zl.getInputStream(resourceName, &aProc)
  end

  def alreadyLoaded?(moduleName)
    moduleRE = Regexp.new("^"+moduleName+"(\.rb|\.so|\.dll|\.o)?$")
    $".detect { |e| e =~ moduleRE } != nil
  end

  def ensureRbExtension(aString)
    aString.sub(/(\.rb)?$/i, ".rb")
  end
end
