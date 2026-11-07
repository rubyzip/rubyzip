# frozen_string_literal: true

module Zip
  class ExtraField::Generic # :nodoc:
    def self.register_map
      return unless const_defined?(:HEADER_ID)

      # Set the name now: a non-main Ractor cannot set it later.
      name
      ::Zip::ExtraField.register(const_get(:HEADER_ID), self)
    end

    def self.name
      @name ||= to_s.split('::').last.downcase.to_sym
    end

    # return field [size, content] or false
    def initial_parse(binstr)
      return false unless binstr

      if binstr[0, 2] != self.class.const_get(:HEADER_ID)
        warn 'WARNING: weird extra field header ID. Skip parsing it.'
        return false
      end

      [binstr[2, 2].unpack1('v'), binstr[4..]]
    end

    # Default strategy is to suppress all extra fields if we're asked to.
    # Specific extra field types can override this if they need to be kept.
    def suppress?
      true
    end

    def to_local_bin
      s = pack_for_local
      (self.class.const_get(:HEADER_ID) + [s.bytesize].pack('v')) << s
    end

    def to_c_dir_bin
      s = pack_for_c_dir
      (self.class.const_get(:HEADER_ID) + [s.bytesize].pack('v')) << s
    end
  end
end
