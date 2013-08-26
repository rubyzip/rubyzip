module Zip
  # Info-ZIP Extra for Zip64 size
  class ExtraField::Zip64 < ExtraField::Generic
    attr_accessor :original_size, :compressed_size, :relative_header_offset, :disk_start_number
    HEADER_ID = "\001\000"
    register_map

    def initialize(binstr = nil)
      @original_size          = nil
      @compressed_size        = nil
      @relative_header_offset = nil
      @disk_start_number      = nil
      binstr and merge(binstr)
    end

    def merge(binstr)
      return if binstr.empty?
      id, size, @original_size, @compressed_size, @relative_header_offset, @disk_start_number = binstr.to_s.unpack("vvQQQV")
    end

    def pack_for_local
      return '' unless @original_size && @compressed_sie && @relative_header_offset && @disk_start_number
      [1, 16, @original_size, @compressed_size, @relative_header_offset, @disk_start_number].pack("vvQQQV")
    end

    def pack_for_c_dir
      pack_for_local
    end
  end
end
