unless Enumerable.instance_methods(true).include?("inject")
  module Enumerable  #:nodoc:all
    def inject(n = 0)
      each { |value| n = yield(n, value) }
      n
    end
  end
end

class String
  def starts_with(aString)
    slice(0, aString.size) == aString
  end

  def ends_with(aString)
    aStringSize = aString.size
    slice(-aStringSize, aStringSize) == aString 
  end

  def ensure_end(aString)
    ends_with(aString) ? self : self + aString
  end

end

class Time
  
  #MS-DOS File Date and Time format as used in Interrupt 21H Function 57H:
  # 
  # Register CX, the Time:
  # Bits 0-4  2 second increments (0-29)
  # Bits 5-10 minutes (0-59)
  # bits 11-15 hours (0-24)
  # 
  # Register DX, the Date:
  # Bits 0-4 day (1-31)
  # bits 5-8 month (1-12)
  # bits 9-15 year (four digit year minus 1980)
  
  
  def to_binary_dos_date
    (sec/2) +
      (min  << 5) +
      (hour << 11)
  end

  def to_binary_dos_time
    (day) +
      (month << 5) +
      ((year - 1980) << 9)
  end

  # Dos time is only stored with two seconds accuracy
  def dos_equals(other)
    (year  == other.year   &&
     month == other.month  &&
     day   == other.day    &&
     hour  == other.hour   &&
     min   == other.min &&
     sec/2 == other.sec/2)
  end

  def self.parse_binary_dos_format(binaryDosDate, binaryDosTime)
    second = 2 * (       0b11111 & binaryDosTime)
    minute = (     0b11111100000 & binaryDosTime) >> 5 
    hour   = (0b1111100000000000 & binaryDosTime) >> 11
    day    = (           0b11111 & binaryDosDate) 
    month  = (       0b111100000 & binaryDosDate) >> 5
    year   = ((0b1111111000000000 & binaryDosDate) >> 9) + 1980
    begin
      return Time.local(year, month, day, hour, minute, second)
    end
  end
end

class Module
  def forward_message(forwarder, *messagesToForward)
    methodDefs = messagesToForward.map { 
      |msg| 
      "def #{msg}; #{forwarder}(:#{msg}); end"
    }
    module_eval(methodDefs.join("\n"))
  end
end


# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
