require 'test_helper'

class TraditionalEncrypterTest < MiniTest::Test
  def setup
    @encrypter = ::Zip::TraditionalEncrypter.new('password')
  end

  def test_header_bytesize
    assert_equal 12, @encrypter.header_bytesize
  end

  def test_gp_flags
    assert_equal 1, @encrypter.gp_flags
  end

  def test_header
    @encrypter.reset!
    exepected = [239, 57, 234, 154, 246, 80, 83, 221, 74, 200, 116, 154].pack("C*")
    Random.stub(:rand, 1) do
      assert_equal exepected, @encrypter.header(0xffffffff)
    end
  end

  def test_encrypt
    @encrypter.reset!
    Random.stub(:rand, 1) { @encrypter.header(0xffffffff) }
    assert_raises(NoMethodError) { @encrypter.encrypt(nil) }
    assert_raises(NoMethodError) { @encrypter.encrypt(1) }
    assert_equal '', @encrypter.encrypt('')
    assert_equal [2, 25, 13, 222, 17, 190, 250, 133, 133, 166].pack("C*"), @encrypter.encrypt('a' * 10)
  end

  def test_reset!
    @encrypter.reset!
    Random.stub(:rand, 1) { @encrypter.header(0xffffffff) }
    [2, 25, 13, 222, 17, 190, 250, 133, 133, 166].map(&:chr).each do |c|
      assert_equal c, @encrypter.encrypt('a')
    end
    assert_equal 134.chr, @encrypter.encrypt('a')
    @encrypter.reset!
    Random.stub(:rand, 1) { @encrypter.header(0xffffffff) }
    [2, 25, 13, 222, 17, 190, 250, 133, 133, 166].map(&:chr).each do |c|
      assert_equal c, @encrypter.encrypt('a')
    end
  end
end

class TraditionalDecrypterTest < MiniTest::Test
  def setup
    @decrypter = ::Zip::TraditionalDecrypter.new('password')
  end

  def test_header_bytesize
    assert_equal 12, @decrypter.header_bytesize
  end

  def test_gp_flags
    assert_equal 1, @decrypter.gp_flags
  end

  def test_decrypt
    @decrypter.reset!([239, 57, 234, 154, 246, 80, 83, 221, 74, 200, 116, 154].pack("C*"))
    [2, 25, 13, 222, 17, 190, 250, 133, 133, 166].map(&:chr).each do |c|
      assert_equal 'a', @decrypter.decrypt(c)
    end
  end

  def test_reset!
    @decrypter.reset!([239, 57, 234, 154, 246, 80, 83, 221, 74, 200, 116, 154].pack("C*"))
    [2, 25, 13, 222, 17, 190, 250, 133, 133, 166].map(&:chr).each do |c|
      assert_equal 'a', @decrypter.decrypt(c)
    end
    assert_equal 229.chr, @decrypter.decrypt(2.chr)
    @decrypter.reset!([239, 57, 234, 154, 246, 80, 83, 221, 74, 200, 116, 154].pack("C*"))
    [2, 25, 13, 222, 17, 190, 250, 133, 133, 166].map(&:chr).each do |c|
      assert_equal 'a', @decrypter.decrypt(c)
    end
  end
end
