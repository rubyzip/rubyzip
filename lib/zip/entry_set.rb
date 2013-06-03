module Zip
  class EntrySet #:nodoc:all
    include Enumerable
    attr_accessor :entry_set, :entry_order

    def initialize(an_enumerable = [])
      super()
      @entry_set   = {}
      @entry_order = []
      an_enumerable.each { |o| push(o) }
    end

    def include?(entry)
      @entry_set.include?(to_key(entry))
    end

    def find_entry(entry)
      @entry_set[to_key(entry)]
    end

    def <<(entry)
      @entry_order.delete(to_key(entry))
      @entry_order << to_key(entry)
      @entry_set[to_key(entry)] = entry
    end

    alias :push :<<

    def size
      @entry_set.size
    end

    alias :length :size

    def delete(entry)
      if @entry_order.delete(to_key(entry)) && @entry_set.delete(to_key(entry))
        entry
      else
        nil
      end
    end

    def each(&block)
      @entry_order.each do |key|
        block.call @entry_set[key]
      end
    end

    def entries
      @entry_order.map { |key| @entry_set[key] }
    end

    # deep clone
    def dup
      EntrySet.new(@entry_order.map { |key| @entry_set[key].dup })
    end

    def ==(other)
      return false unless other.kind_of?(EntrySet)
      @entry_set == other.entry_set && @entry_order == other.entry_order
    end

    def parent(entry)
      @entry_set[to_key(entry.parent_as_string)]
    end

    def glob(pattern, flags = ::File::FNM_PATHNAME|::File::FNM_DOTMATCH)
      entries.map do |entry|
        next nil unless ::File.fnmatch(pattern, entry.name.chomp('/'), flags)
        yield(entry) if block_given?
        entry
      end.compact
    end

    protected

    private
    def to_key(entry)
      entry.to_s.sub(/\/$/, '')
    end
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
