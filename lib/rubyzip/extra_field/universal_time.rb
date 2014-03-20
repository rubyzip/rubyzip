module RubyZip
  # Info-ZIP Additional timestamp field
  class ExtraField::UniversalTime < ExtraField::Generic
    HEADER_ID = "UT"
    register_map

    def initialize(binstr = nil)
      @ctime = nil
      @mtime = nil
      @atime = nil
      @flag  = nil
      binstr and merge(binstr)
    end

    attr_accessor :atime, :ctime, :mtime, :flag

    def merge(binstr)
      return if binstr.empty?
      size, content = initial_parse(binstr)
      size or return
      @flag, mtime, atime, ctime = content.unpack("CVVV")
      mtime and @mtime ||= ::RubyZip::DOSTime.at(mtime)
      atime and @atime ||= ::RubyZip::DOSTime.at(atime)
      ctime and @ctime ||= ::RubyZip::DOSTime.at(ctime)
    end

    def ==(other)
      @mtime == other.mtime &&
        @atime == other.atime &&
        @ctime == other.ctime
    end

    def pack_for_local
      s = [@flag].pack("C")
      @flag & 1 != 0 and s << [@mtime.to_i].pack("V")
      @flag & 2 != 0 and s << [@atime.to_i].pack("V")
      @flag & 4 != 0 and s << [@ctime.to_i].pack("V")
      s
    end

    def pack_for_c_dir
      s = [@flag].pack("C")
      @flag & 1 == 1 and s << [@mtime.to_i].pack("V")
      s
    end
  end
end