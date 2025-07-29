# frozen_string_literal: true

require 'test_helper'

class VersionTest < Minitest::Test
  def test_version
    # Ensure all our versions numbers have at least MAJOR.MINOR.PATCH
    # elements separated by dots, to comply with Semantic Versioning.
    assert_match(/^\d+\.\d+\.\d+/, Zip::VERSION)
  end
end
