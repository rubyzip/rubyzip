# frozen_string_literal: true

require_relative 'test_helper'

class ZipExtraFieldUnknownTest < Minitest::Test
  def test_new
    extra = ::Zip::ExtraField::Unknown.new
    assert_empty(extra.to_c_dir_bin)
    assert_empty(extra.to_local_bin)
  end

  def test_merge_cdir_then_local
    extra = ::Zip::ExtraField::Unknown.new
    field = "ux\v\x00\x01\x04\xF6\x01\x00\x00\x04\x14\x00\x00\x00"

    extra.merge(field)
    assert_empty(extra.to_local_bin)
    assert_equal(field, extra.to_c_dir_bin)

    extra.merge(field, local: true)
    assert_equal(field, extra.to_local_bin)
    assert_equal(field, extra.to_c_dir_bin)
  end

  def test_merge_local_only
    extra = ::Zip::ExtraField::Unknown.new
    field = "ux\v\x00\x01\x04\xF6\x01\x00\x00\x04\x14\x00\x00\x00"

    extra.merge(field, local: true)
    assert_equal(field, extra.to_local_bin)
    assert_empty(extra.to_c_dir_bin)
  end

  def test_equality
    extra1 = ::Zip::ExtraField::Unknown.new
    extra2 = ::Zip::ExtraField::Unknown.new
    assert_equal(extra1, extra2)

    extra1.merge("ux\v\x00\x01\x04\xF6\x01\x00\x00\x04\x14\x00\x00\x00")
    refute_equal(extra1, extra2)

    extra2.merge("ux\v\x00\x01\x04\xF6\x01\x00\x00\x04\x14\x00\x00\x00")
    assert_equal(extra1, extra2)

    extra1.merge('foo', local: true)
    refute_equal(extra1, extra2)

    extra2.merge('foo', local: true)
    assert_equal(extra1, extra2)
  end
end
