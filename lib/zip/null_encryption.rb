module Zip
  module NullEncryption
    def header_bytesize
      0
    end

    def gp_flags
      0
    end
  end

  class NullEncrypter
    include NullEncryption

    def header(crc32)
      ''
    end

    def encrypt(data)
      data
    end

    def reset!
    end
  end

  class NullDecrypter
    include NullEncryption

    def decrypt(data)
      data
    end

    def reset!(header)
    end
  end
end
