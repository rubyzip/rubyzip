# frozen_string_literal: true

module Zip
  module IOExtras # :nodoc:
    module FakeIO # :nodoc:
      attr_reader :external_encoding, :internal_encoding

      def initialize(**opts)
        @internal_encoding = Encoding.find(opts[:internal_encoding]) if opts[:internal_encoding]

        if opts[:encoding].kind_of?(String)
          _ext, int = opts[:encoding].split(':', 2)
          @internal_encoding = Encoding.find(int) unless @internal_encoding || int.nil?
        end

        @external_encoding = Encoding::ASCII_8BIT
      end

      def set_encoding(ext_enc, int_enc = nil)
        if ext_enc.kind_of?(String) && ext_enc.include?(':')
          _ext_enc, int_enc = ext_enc.split(':', 2)
        end

        begin
          @internal_encoding = Encoding.find(int_enc) if int_enc
        rescue ArgumentError
          warn "warning: Unsupported encoding #{int_enc} ignored"
        end

        @external_encoding = Encoding::ASCII_8BIT
      end

      # Implement kind_of? in order to pretend to be an IO object.
      def kind_of?(object)
        object == IO || super
      end
    end
  end
end
