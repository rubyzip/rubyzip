# frozen_string_literal: true

module ExtraAssertions
  def assert_forwarded(object, method, ret_val, *expected_args)
    call_args = nil
    object.singleton_class.class_exec do
      alias_method :"#{method}_org", method
      define_method(method) do |*args|
        call_args = args
        ret_val
      end
    end

    assert_equal(ret_val, yield) # Invoke test
    assert_equal(expected_args, call_args)
  ensure
    object.singleton_class.class_exec do
      remove_method method
      alias_method method, :"#{method}_org"
    end
  end
end
