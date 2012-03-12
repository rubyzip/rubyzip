module Zip
  class << self
    def options
      @options ||= {
        :overwrite_existing_element = false
      }
    end
  end
end
