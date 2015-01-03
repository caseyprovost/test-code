require "minitest/autorun"
require File.join(File.dirname(__FILE__), '..', 'parser')

class TestParser < Minitest::Test
  def setup
    @parser = Parser.new(File.join(File.dirname(__FILE__), '..', 'fixtures/test_file.out'))
  end

  def test_call
    assert_equal true, @parser.call
  end

  # def test_that_it_will_not_blend
  #   refute_match /^no/i, @meme.will_it_blend?
  # end

  def test_that_will_be_skipped
    skip "test this later"
  end
end
