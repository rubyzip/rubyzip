# encoding: utf-8

require 'test_helper'

class Bzip2ErrorsTest < MiniTest::Test
  def test_bzip2_error
    raise ::Zip::Bzip2::Error
  rescue ::Zip::Bzip2::Error
  end

  def test_bzip2_mem_error
    raise ::Zip::Bzip2::MemError
  rescue ::Zip::Bzip2::Error
  end

  def test_bzip2_data_error
    raise ::Zip::Bzip2::DataError
  rescue ::Zip::Bzip2::Error
  end

  def test_bzip2_magic_data_error
    raise ::Zip::Bzip2::MagicDataError
  rescue ::Zip::Bzip2::Error
  end

  def test_bzip2_config_error
    raise ::Zip::Bzip2::ConfigError
  rescue ::Zip::Bzip2::Error
  end

  def test_bzip2_unexpected_error
    raise ::Zip::Bzip2::UnexpectedError, -999
  rescue ::Zip::Bzip2::Error
  end
end
