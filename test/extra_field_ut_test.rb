require 'test_helper'

class ZipExtraFieldUTTest < MiniTest::Test

  PARSE_TESTS = [
    ["UT\x05\x00\x01PS>A", 0b001, true, true, false],
    ["UT\x05\x00\x02PS>A", 0b010, false, true, true],
    ["UT\x05\x00\x04PS>A", 0b100, true, false, true],
    ["UT\x09\x00\x03PS>APS>A", 0b011, false, true, false],
    ["UT\x09\x00\x05PS>APS>A", 0b101, true, false, false],
    ["UT\x09\x00\x06PS>APS>A", 0b110, false, false, true],
    ["UT\x13\x00\x07PS>APS>APS>A", 0b111, false, false, false]
  ]

  def test_parse
    PARSE_TESTS.each do |bin, flags, a, c, m|
      ut = ::Zip::ExtraField::UniversalTime.new(bin)
      assert_equal(flags, ut.flag)
      assert(ut.atime.nil? == a)
      assert(ut.ctime.nil? == c)
      assert(ut.mtime.nil? == m)
    end
  end

  def test_parse_size_zero
    ut = ::Zip::ExtraField::UniversalTime.new("UT\x00")
    assert_equal(0b000, ut.flag)
    assert_nil(ut.atime)
    assert_nil(ut.ctime)
    assert_nil(ut.mtime)
  end

  def test_parse_size_nil
    ut = ::Zip::ExtraField::UniversalTime.new('UT')
    assert_equal(0b000, ut.flag)
    assert_nil(ut.atime)
    assert_nil(ut.ctime)
    assert_nil(ut.mtime)
  end

  def test_parse_nil
    ut = ::Zip::ExtraField::UniversalTime.new
    assert_equal(0b000, ut.flag)
    assert_nil(ut.atime)
    assert_nil(ut.ctime)
    assert_nil(ut.mtime)
  end

  def test_set_clear_times
    time = ::Zip::DOSTime.now
    ut = ::Zip::ExtraField::UniversalTime.new
    assert_equal(0b000, ut.flag)

    ut.mtime = time
    assert_equal(0b001, ut.flag)
    assert_equal(time, ut.mtime)

    ut.ctime = time
    assert_equal(0b101, ut.flag)
    assert_equal(time, ut.ctime)

    ut.atime = time
    assert_equal(0b111, ut.flag)
    assert_equal(time, ut.atime)

    ut.ctime = nil
    assert_equal(0b011, ut.flag)
    assert_nil ut.ctime

    ut.mtime = nil
    assert_equal(0b010, ut.flag)
    assert_nil ut.mtime

    ut.atime = nil
    assert_equal(0b000, ut.flag)
    assert_nil ut.atime
  end

  def test_pack
    time = ::Zip::DOSTime.at('PS>A'.unpack1('l<'))
    ut = ::Zip::ExtraField::UniversalTime.new
    assert_equal("\x00", ut.pack_for_local)
    assert_equal("\x00", ut.pack_for_c_dir)

    ut.mtime = time
    assert_equal("\x01PS>A", ut.pack_for_local)
    assert_equal("\x01PS>A", ut.pack_for_c_dir)

    ut.atime = time
    assert_equal("\x03PS>APS>A", ut.pack_for_local)
    assert_equal("\x03PS>A", ut.pack_for_c_dir)

    ut.ctime = time
    assert_equal("\x07PS>APS>APS>A", ut.pack_for_local)
    assert_equal("\x07PS>A", ut.pack_for_c_dir)
  end
end
