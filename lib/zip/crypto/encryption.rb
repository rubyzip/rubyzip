module Zip
  class Encrypter #:nodoc:all
    def self.build(password)
      if password.nil? or password.empty?
        NullEncrypter.new
      else
        TraditionalEncrypter.new(password)
      end
    end
  end

  class Decrypter
    def self.build(password)
      if password.nil? or password.empty?
        NullDecrypter.new
      else
        TraditionalDecrypter.new(password)
      end
    end
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
