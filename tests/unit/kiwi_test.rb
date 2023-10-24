require File.dirname(__FILE__) + "/../test_helper"

class KiwiTest < ActiveSupport::TestCase
  #   plugin_fixtures :kb_articles

  # Replace this with your real tests.
  def test_truth
    assert true
  end

  test "should not save category without title" do
    assert true, "Saved the category without a title"
  end
end
