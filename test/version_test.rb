# frozen_string_literal: true

require 'test_helper'
require 'zip/version'

class VersionTest < MiniTest::Test
  def test_version
    # Ensure all our versions numbers have at least MAJOR.MINOR.PATCH
    # elements separated by dots, to comply with Semantic Versioning.
    assert_match(/^\d+\.\d+\.\d+/, Zip::VERSION)
  end
end
