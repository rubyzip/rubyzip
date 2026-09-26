# frozen_string_literal: true

module Zip
  # Old Info-ZIP Extra for UNIX uid/gid and file timestamps
  class ExtraField::OldUnix < ExtraField::Generic # :nodoc:
    HEADER_ID = 'UX'
    register_map

    TIMES_SIZE = 8
    OWNER_SIZE = 4

    def initialize(binstr = nil)
      @uid = nil
      @gid = nil
      @atime = nil
      @mtime = nil
      binstr && merge(binstr)
    end

    attr_accessor :uid, :gid, :atime, :mtime

    def merge(binstr)
      return if binstr.empty?

      size, content = initial_parse(binstr)
      # size: 8 for central directory. 8 or 12 for local header, as the UID
      # and GID are optional there.
      return if !size || size == 0

      if content.bytesize >= TIMES_SIZE
        atime, mtime = content.unpack('VV')
        @atime ||= atime
        @mtime ||= mtime
      end

      # UID and GID are either both present or both absent.
      return unless content.bytesize >= TIMES_SIZE + OWNER_SIZE

      uid, gid = content[TIMES_SIZE, OWNER_SIZE].unpack('vv')
      @uid ||= uid
      @gid ||= gid # rubocop:disable Naming/MemoizedInstanceVariableName
    end

    def ==(other)
      @uid == other.uid &&
        @gid == other.gid &&
        @atime == other.atime &&
        @mtime == other.mtime
    end

    # The UID and GID are optional in the local header, so only write them if
    # we have both. The timestamps must be present for the layout to be valid.
    def pack_for_local
      s = pack_for_c_dir
      s << [@uid, @gid].pack('vv') if !s.empty? && @uid && @gid
      s
    end

    def pack_for_c_dir
      [@atime, @mtime].pack('VV')
    end
  end
end
