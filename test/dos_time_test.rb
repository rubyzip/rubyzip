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
