# frozen_string_literal: true

require_relative 'test_helper'

require 'zip/dos_time'

class DOSTimeTest < Minitest::Test
  def setup
    @dos_time = Zip::DOSTime.new(2022, 1, 1, 12, 0, 0)
  end

  def test_new
    dos_time = Zip::DOSTime.new
    assert(dos_time.absolute_time?)

    dos_time = Zip::DOSTime.new(2022, 1, 1, 12, 0, 0)
    assert(dos_time.absolute_time?)

    dos_time = Zip::DOSTime.new(2022, 1, 1, 12, 0, 0, 0)
    assert(dos_time.absolute_time?)
  end

  def test_now
    dos_time = Zip::DOSTime.now
    assert(dos_time.absolute_time?)
  end

  def test_utc
    dos_time = Zip::DOSTime.utc(2022, 1, 1, 12, 0, 0)
    assert(dos_time.absolute_time?)
  end

  def test_gm
    dos_time = Zip::DOSTime.gm(2022, 1, 1, 12, 0, 0)
    assert(dos_time.absolute_time?)
  end

  def test_mktime
    dos_time = Zip::DOSTime.mktime(2022, 1, 1, 12, 0, 0)
    assert(dos_time.absolute_time?)
  end

  def test_from_time
    time = Time.new(2022, 1, 1, 12, 0, 0)
    dos_time = Zip::DOSTime.from_time(time)
    assert_equal(@dos_time, dos_time)
    assert(dos_time.absolute_time?)
  end

  def test_parse_binary_dos_format
    bin_dos_date = 0b101010000100001
    bin_dos_time = 0b110000000000000
    dos_time = Zip::DOSTime.parse_binary_dos_format(bin_dos_date, bin_dos_time)
    assert_equal(@dos_time, dos_time)
    refute(dos_time.absolute_time?)
  end

  def test_at
    time = Time.at(1_641_038_400)
    dos_time = Zip::DOSTime.at(1_641_038_400)
    assert_equal(time, dos_time)
    assert(dos_time.absolute_time?)
  end

  def test_binary_dos_fields_are_clamped_to_the_representable_range
    # The DOS date field holds "year - 1980" in seven bits, so only
    # 1980-01-01 00:00:00 .. 2107-12-31 23:59:58 fits. Out-of-range years
    # used to wrap, writing a valid-looking but wrong date.
    assert_equal(0x0021, Zip::DOSTime.local(1980, 1, 1, 0, 0, 0).to_binary_dos_date)
    assert_equal(0x0000, Zip::DOSTime.local(1980, 1, 1, 0, 0, 0).to_binary_dos_time)
    assert_equal(0xff9f, Zip::DOSTime.local(2107, 12, 31, 23, 59, 58).to_binary_dos_date)
    assert_equal(0xbf7d, Zip::DOSTime.local(2107, 12, 31, 23, 59, 58).to_binary_dos_time)

    # below the epoch: clamp to the floor, do not wrap into the future
    [1970, 1979].each do |year|
      dos_time = Zip::DOSTime.local(year, 6, 15, 12, 30, 30)
      assert_equal(0x0021, dos_time.to_binary_dos_date, "year #{year} date")
      assert_equal(0x0000, dos_time.to_binary_dos_time, "year #{year} time")
    end

    # above the last representable year: clamp to the ceiling
    dos_time = Zip::DOSTime.local(2108, 6, 15, 12, 30, 30)
    assert_equal(0xff9f, dos_time.to_binary_dos_date)
    assert_equal(0xbf7d, dos_time.to_binary_dos_time)

    # every clamped value still has to fit the 16-bit field
    [1970, 1979, 1980, 2022, 2107, 2108].each do |year|
      dos_time = Zip::DOSTime.local(year, 6, 15, 12, 30, 30)
      assert_includes(0..0xffff, dos_time.to_binary_dos_date, "year #{year}")
      assert_includes(0..0xffff, dos_time.to_binary_dos_time, "year #{year}")
    end
  end

  def test_local
    dos_time = Zip::DOSTime.local(2022, 1, 1, 12, 0, 0)
    assert(dos_time.absolute_time?)
  end

  def test_comparison
    time = Time.new(2022, 1, 1, 12, 0, 0)
    assert_equal(0, @dos_time <=> time)
  end

  def test_jruby_cmp
    return unless defined? JRUBY_VERSION && Gem::Version.new(JRUBY_VERSION) < '9.2.18.0'

    time = Time.new(2022, 1, 1, 12, 0, 0)
    assert(@dos_time == time)
    assert(@dos_time <= time)
    assert(@dos_time >= time)

    time = Time.new(2022, 1, 1, 12, 1, 1)
    assert(time > @dos_time)
    assert(@dos_time < time)
  end
end
