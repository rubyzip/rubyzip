module Zip
  # Info-ZIP Extra for AES encryption
  class ExtraField::AES < ExtraField::Generic
    attr_reader :data_size, :vendor_version, :vendor_id, :encryption_strength, :compression_method
    HEADER_ID = "\x01\x99".force_encoding("ASCII-8BIT")
    register_map

    def initialize(binstr = nil)
      @data_size = nil
      @vendor_version = nil
      @vendor_id = nil
      @encryption_strength = nil
      @compression_method = nil
      binstr and merge(binstr)
    end

    def merge(binstr)
      return if binstr.empty?
      _, @data_size, @vendor_version, @vendor_id, @encryption_strength, @compression_method = binstr.to_s.unpack("vvva2Cv")
    end

    def pack_for_local
      return '' unless @data_size && @vendor_version && @vendor_id && @encryption_strength && @compression_method
      [0x01, 0x99, @data_size, @vendor_version, @vendor_id, @encryption_strength, @compression_method].pack("vvvvM2Cv")
    end

    def pack_for_c_dir
      pack_for_local
    end
  end
end
