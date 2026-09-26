# frozen_string_literal: true

require_relative 'test_helper'

class ZipExtraFieldOldUnixTest < Minitest::Test
  ATIME = 1_000_000_000
  MTIME = 1_100_000_000
  UID = 1000
  GID = 100

  TIMES = [ATIME, MTIME].pack('VV').freeze
  OWNER = [UID, GID].pack('vv').freeze

  LOCAL_FULL = "UX\x0c\x00#{TIMES}#{OWNER}".b.freeze
  LOCAL_TIMES = "UX\x08\x00#{TIMES}".b.freeze
  C_DIR = "UX\x08\x00#{TIMES}".b.freeze
  LOCAL_UID_ONLY = "UX\x0a\x00#{TIMES}#{[UID].pack('v')}".b.freeze

  def test_parse_local_with_owner
    ux = Zip::ExtraField::OldUnix.new(LOCAL_FULL)
    assert_equal(ATIME, ux.atime)
    assert_equal(MTIME, ux.mtime)
    assert_equal(UID, ux.uid)
    assert_equal(GID, ux.gid)
  end

  def test_parse_local_without_owner
    ux = Zip::ExtraField::OldUnix.new(LOCAL_TIMES)
    assert_equal(ATIME, ux.atime)
    assert_equal(MTIME, ux.mtime)
    assert_nil(ux.uid)
    assert_nil(ux.gid)
  end

  def test_parse_c_dir
    ux = Zip::ExtraField::OldUnix.new(C_DIR)
    assert_equal(ATIME, ux.atime)
    assert_equal(MTIME, ux.mtime)
    assert_nil(ux.uid)
    assert_nil(ux.gid)
  end

  def test_parse_uid_only
    ux = Zip::ExtraField::OldUnix.new(LOCAL_UID_ONLY)
    assert_equal(ATIME, ux.atime)
    assert_equal(MTIME, ux.mtime)
    assert_nil(ux.uid)
    assert_nil(ux.gid)
  end

  def test_parse_truncated
    ux = Zip::ExtraField::OldUnix.new("UX\x04\x00#{[ATIME].pack('V')}")
    assert_nil(ux.atime)
    assert_nil(ux.mtime)
    assert_nil(ux.uid)
    assert_nil(ux.gid)
  end

  def test_parse_size_zero
    ux = Zip::ExtraField::OldUnix.new("UX\x00\x00")
    assert_nil(ux.atime)
    assert_nil(ux.mtime)
    assert_nil(ux.uid)
    assert_nil(ux.gid)
  end

  def test_parse_size_nil
    ux = Zip::ExtraField::OldUnix.new('UX')
    assert_nil(ux.atime)
    assert_nil(ux.mtime)
  end

  def test_parse_nil
    ux = Zip::ExtraField::OldUnix.new
    assert_nil(ux.atime)
    assert_nil(ux.mtime)
    assert_nil(ux.uid)
    assert_nil(ux.gid)
  end

  def test_merge_c_dir_then_local
    ux = Zip::ExtraField::OldUnix.new(C_DIR)
    ux.merge(LOCAL_FULL)
    assert_equal([ATIME, MTIME, UID, GID], [ux.atime, ux.mtime, ux.uid, ux.gid])
  end

  def test_merge_local_then_c_dir
    ux = Zip::ExtraField::OldUnix.new(LOCAL_FULL)
    ux.merge(C_DIR)
    assert_equal([ATIME, MTIME, UID, GID], [ux.atime, ux.mtime, ux.uid, ux.gid])
  end

  def test_pack_local_with_owner
    ux = Zip::ExtraField::OldUnix.new(LOCAL_FULL)
    assert_equal(TIMES + OWNER, ux.pack_for_local)
    assert_equal(LOCAL_FULL, ux.to_local_bin.b)
  end

  def test_pack_local_without_owner
    ux = Zip::ExtraField::OldUnix.new(C_DIR)
    assert_equal(TIMES, ux.pack_for_local)
    assert_equal(LOCAL_TIMES, ux.to_local_bin.b)
  end

  def test_pack_local_uid_only_omits_owner
    ux = Zip::ExtraField::OldUnix.new(C_DIR)
    ux.uid = UID
    assert_equal(TIMES, ux.pack_for_local)

    ux.uid = nil
    ux.gid = GID
    assert_equal(TIMES, ux.pack_for_local)
  end

  def test_pack_c_dir
    ux = Zip::ExtraField::OldUnix.new(LOCAL_FULL)
    assert_equal(TIMES, ux.pack_for_c_dir)
    assert_equal(C_DIR, ux.to_c_dir_bin.b)
  end

  def test_extra_field_c_dir_round_trip
    extra = Zip::ExtraField.new(C_DIR)
    assert(extra.member?(:oldunix))
    assert_equal(LOCAL_TIMES, extra.to_local_bin.b)
    assert_equal(C_DIR, extra.to_c_dir_bin.b)
  end

  def test_extra_field_local_round_trip
    extra = Zip::ExtraField.new(LOCAL_FULL, local: true)
    assert(extra.member?(:oldunix))
    assert_equal(LOCAL_FULL, extra.to_local_bin.b)
    assert_equal(C_DIR, extra.to_c_dir_bin.b)
  end
end
