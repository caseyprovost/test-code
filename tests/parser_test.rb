require "minitest/autorun"
require File.join(File.dirname(__FILE__), '..', 'parser')

class TestParser < Minitest::Test
  def setup
    @parser = Parser.new(File.join(File.dirname(__FILE__), '..', 'fixtures/test_file.out'))
  end

  def test_call
    start_time  = Time.now
    result = @parser.call
    # measure the performance of parsing and writing to CSV
    elapsed_time = ((Time.now - start_time)).to_i
    raise "#{start_time} #{Time.now}".inspect
    raise elapsed_time.inspect

    assert_equal true, result
  end

  # def test_that_it_will_not_blend
  #   refute_match /^no/i, @meme.will_it_blend?
  # end

  def test_that_will_be_skipped
    skip "test this later"
  end
end
