# frozen_string_literal: true

module Zip
  module IOExtras # :nodoc:
    # Implements kind_of? in order to pretend to be an IO object
    module FakeIO # :nodoc:
      def kind_of?(object)
        object == IO || super
      end
    end
  end
end
