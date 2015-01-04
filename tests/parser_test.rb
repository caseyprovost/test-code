require "minitest/autorun"
require File.join(File.dirname(__FILE__), '..', 'parser')

class TestParser < Minitest::Test
  def setup
    @parser = Parser.new(File.join(File.dirname(__FILE__), '..', 'fixtures/test_file.out'))
  end

  def test_call
    # output the performance results of parsing a file
    require "benchmark"
    puts Benchmark.measure{Parser.new(File.join(File.dirname(__FILE__), '..', 'fixtures/test_file.out')).call}

    result = @parser.call
    assert File.exists?(result)
    assert CSV.readlines(result).count == 22 # we know only 22 of the orders should show up in the CSV with the given constraints
  end
end
