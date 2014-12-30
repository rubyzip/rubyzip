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
