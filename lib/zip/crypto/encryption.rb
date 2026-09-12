# frozen_string_literal: true

module Zip
  class Encrypter # :nodoc:all
    def trailer
      ''
    end

    def crc(computed_crc)
      computed_crc
    end

    def prepare_entry(_entry); end
  end

  class Decrypter # :nodoc:all
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
