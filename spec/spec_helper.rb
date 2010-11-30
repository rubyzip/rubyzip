require 'rspec'

require 'gentestfiles'
require 'zip/zip'

Dir.chdir(File.dirname(__FILE__))

module IOizeString
  attr_reader :tell
  
  def read(count = nil)
    @tell ||= 0
    count = size unless count
    retVal = slice(@tell, count)
    @tell += count
    return retVal
  end

  def seek(index, offset)
    @tell ||= 0
    case offset
    when IO::SEEK_END
      newPos = size + index
    when IO::SEEK_SET
      newPos = index
    when IO::SEEK_CUR
      newPos = @tell + index
    else
      raise "Error in test method IOizeString::seek"
    end
    if (newPos < 0 || newPos >= size)
      raise Errno::EINVAL
    else
      @tell=newPos
    end
  end

  def reset
    @tell = 0
  end
end

Rspec.configure do |c|
  include Zip
end
