module Zip
  class << self
    def options
      @options ||= {
        :on_exists_proc_default => false,
        :continue_on_exists_proc_default => false
      }
    end
  end
end
