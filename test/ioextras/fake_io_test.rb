# frozen_string_literal: true

require_relative '../test_helper'

require 'zip/ioextras/fake_io'

class FakeIOTest < Minitest::Test
  class FakeIOUsingClass
    include Zip::IOExtras::FakeIO
  end

  def test_kind_of?
    obj = FakeIOUsingClass.new

    assert(obj.kind_of?(Object))
    assert(obj.kind_of?(FakeIOUsingClass))
    assert(obj.kind_of?(IO))
    assert(!obj.kind_of?(Integer))
    assert(!obj.kind_of?(String))
  end

  def test_initialize_with_no_encoding
    obj = FakeIOUsingClass.new

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_nil(obj.internal_encoding)
  end

  def test_initialize_with_encoding
    obj = FakeIOUsingClass.new(encoding: 'UTF-8:UTF-16LE')

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_equal(Encoding::UTF_16LE, obj.internal_encoding)
  end

  def test_initialize_with_bad_encoding
    assert_raises(ArgumentError) do
      FakeIOUsingClass.new(encoding: 'UTF-8:BAD_ENCODING')
    end
  end

  def test_initialize_with_encoding_just_external
    obj = FakeIOUsingClass.new(encoding: 'UTF-8')

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_nil(obj.internal_encoding)
  end

  def test_initialize_with_external_encoding
    obj = FakeIOUsingClass.new(external_encoding: Encoding::UTF_8)

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_nil(obj.internal_encoding)
  end

  def test_initialize_with_internal_encoding
    obj = FakeIOUsingClass.new(internal_encoding: Encoding::UTF_16LE)

    assert_equal(Encoding::UTF_16LE, obj.internal_encoding)
    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
  end

  def test_initialize_with_external_encoding_as_string
    obj = FakeIOUsingClass.new(external_encoding: 'UTF-8')

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_nil(obj.internal_encoding)
  end

  def test_initialize_with_internal_encoding_as_string
    obj = FakeIOUsingClass.new(internal_encoding: 'UTF-16LE')

    assert_equal(Encoding::UTF_16LE, obj.internal_encoding)
    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
  end

  def test_initialize_with_bad_external_encoding_string
    # assert_raises(ArgumentError) do
    FakeIOUsingClass.new(external_encoding: 'BAD_ENCODING')
    # end
  end

  def test_initialize_with_bad_internal_encoding_string
    assert_raises(ArgumentError) do
      FakeIOUsingClass.new(internal_encoding: 'BAD_ENCODING')
    end
  end

  def test_initialize_with_internal_and_external_encoding
    obj = FakeIOUsingClass.new(external_encoding: Encoding::UTF_8, internal_encoding: Encoding::UTF_16LE)

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_equal(Encoding::UTF_16LE, obj.internal_encoding)
  end

  def test_initialize_with_internal_and_external_encoding_as_strings
    obj = FakeIOUsingClass.new(external_encoding: 'UTF-8', internal_encoding: 'UTF-16LE')

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_equal(Encoding::UTF_16LE, obj.internal_encoding)
  end

  def test_initialize_with_encoding_and_external_encoding
    obj = FakeIOUsingClass.new(encoding: 'UTF-8:UTF-16LE', external_encoding: Encoding::ISO_8859_1)

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_equal(Encoding::UTF_16LE, obj.internal_encoding)
  end

  def test_initialize_with_encoding_and_internal_encoding
    obj = FakeIOUsingClass.new(encoding: 'UTF-8:UTF-16LE', internal_encoding: Encoding::UTF_32LE)

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_equal(Encoding::UTF_32LE, obj.internal_encoding)
  end

  def test_initialize_with_all_encoding_options
    obj = FakeIOUsingClass.new(encoding: 'UTF-8:UTF-16LE', external_encoding: Encoding::ISO_8859_1, internal_encoding: Encoding::UTF_32LE)

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_equal(Encoding::UTF_32LE, obj.internal_encoding)
  end

  def test_set_encoding_with_external_encoding
    obj = FakeIOUsingClass.new
    obj.set_encoding(Encoding::UTF_8)

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_nil(obj.internal_encoding)
  end

  def test_set_encoding_with_external_encoding_as_string
    obj = FakeIOUsingClass.new
    obj.set_encoding('UTF-8')

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_nil(obj.internal_encoding)
  end

  def test_set_encoding_with_bad_external_encoding
    obj = FakeIOUsingClass.new

    assert_silent do
      obj.set_encoding('BAD_ENCODING')
    end
  end

  def test_set_encoding_with_external_and_internal_encoding
    obj = FakeIOUsingClass.new
    obj.set_encoding(Encoding::UTF_8, Encoding::UTF_16LE)

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_equal(Encoding::UTF_16LE, obj.internal_encoding)
  end

  def test_set_encoding_with_external_and_internal_encoding_as_strings
    obj = FakeIOUsingClass.new
    obj.set_encoding('UTF-8', 'UTF-16LE')

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_equal(Encoding::UTF_16LE, obj.internal_encoding)
  end

  def test_set_encoding_with_bad_internal_encoding
    obj = FakeIOUsingClass.new
    assert_output('', /warning: Unsupported encoding BAD_ENCODING ignored/) do
      obj.set_encoding(Encoding::UTF_8, 'BAD_ENCODING')
    end
  end

  def test_set_encoding_with_external_and_internal_encoding_as_single_string
    obj = FakeIOUsingClass.new
    obj.set_encoding('UTF-8:UTF-16LE')

    assert_equal(Encoding::ASCII_8BIT, obj.external_encoding)
    assert_equal(Encoding::UTF_16LE, obj.internal_encoding)
  end

  def test_set_encoding_with_bad_external_and_internal_encoding_as_single_string
    obj = FakeIOUsingClass.new
    assert_output('', /warning: Unsupported encoding BAD_ENCODING! ignored/) do
      obj.set_encoding('BAD_ENCODING:BAD_ENCODING!')
    end
  end
end
