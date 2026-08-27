# frozen_string_literal: true

require 'rubygems'

module Zip
  class DOSTime < Time # :nodoc:all
    # MS-DOS File Date and Time format as used in Interrupt 21H Function 57H:

    # Register CX, the Time:
    # Bits 0-4  2 second increments (0-29)
    # Bits 5-10 minutes (0-59)
    # bits 11-15 hours (0-24)

    # Register DX, the Date:
    # Bits 0-4 day (1-31)
    # bits 5-8 month (1-12)
    # bits 9-15 year (four digit year minus 1980)

    # The MS-DOS date field is seven bits of "year minus 1980", so only
    # 1980-01-01 00:00:00 through 2107-12-31 23:59:58 can be represented.
    # Times outside that are clamped rather than allowed to wrap: the real
    # time is still carried in the universal time (UT) extra field, but the
    # DOS fields have to stay in range for readers that only look at those.
    DOS_EPOCH_YEAR = 1980
    DOS_MAX_YEAR = 2107
    DOS_MIN_DATE = 0x0021 # 1980-01-01
    DOS_MAX_DATE = 0xff9f # 2107-12-31
    DOS_MIN_TIME = 0x0000 # 00:00:00
    DOS_MAX_TIME = 0xbf7d # 23:59:58

    attr_writer :absolute_time # :nodoc:

    def absolute_time?
      # If absolute time is not set, we can assume it is an absolute time
      # because times do have timezone information by default.
      @absolute_time.nil? || @absolute_time
    end

    def to_binary_dos_time
      return DOS_MIN_TIME if year < DOS_EPOCH_YEAR
      return DOS_MAX_TIME if year > DOS_MAX_YEAR

      (sec / 2) +
        (min << 5) +
        (hour << 11)
    end

    def to_binary_dos_date
      return DOS_MIN_DATE if year < DOS_EPOCH_YEAR
      return DOS_MAX_DATE if year > DOS_MAX_YEAR

      day +
        (month << 5) +
        ((year - DOS_EPOCH_YEAR) << 9)
    end

    # Deprecated. Remove for version 4.
    def dos_equals(other) # rubocop:disable Naming/PredicateMethod
      warn 'Zip::DOSTime#dos_equals is deprecated. Use `==` instead.'
      self == other
    end

    # Dos time is only stored with two seconds accuracy.
    def <=>(other)
      return unless other.kind_of?(Time)

      (to_i / 2) <=> (other.to_i / 2)
    end

    # Create a DOSTime instance from a vanilla Time instance.
    def self.from_time(time)
      local(time.year, time.month, time.day, time.hour, time.min, time.sec)
    end

    def self.parse_binary_dos_format(bin_dos_date, bin_dos_time)
      second = 2 * (0b11111 & bin_dos_time)
      minute = (0b11111100000 & bin_dos_time) >> 5
      hour   = (0b1111100000000000 & bin_dos_time) >> 11
      day    = (0b11111 & bin_dos_date)
      month  = (0b111100000 & bin_dos_date) >> 5
      year   = ((0b1111111000000000 & bin_dos_date) >> 9) + 1980

      time = local(year, month, day, hour, minute, second)
      time.absolute_time = false
      time
    end

    if defined? JRUBY_VERSION && Gem::Version.new(JRUBY_VERSION) < '9.2.18.0'
      module JRubyCMP # :nodoc:
        def ==(other)
          (self <=> other).zero?
        end

        def <(other)
          (self <=> other).negative?
        end

        def <=(other)
          (self <=> other) <= 0
        end

        def >(other)
          (self <=> other).positive?
        end

        def >=(other)
          (self <=> other) >= 0
        end
      end

      include JRubyCMP
    end
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
