#!/usr/bin/env ruby
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..')

require 'test/helper'

# Class for testing SampleReader.
class TestSampleReader < Test::Unit::TestCase
  DATA1 = <<-DATA.gsub(/^\s+\|/, '')
            |#ID\tIndex1\tIndex2
            |A\tATCG\tTCCG
            |B\tATCG\tTCCC
          DATA

  DATA2 = <<-DATA.gsub(/^\s+\|/, '')
            |#ID\tIndex1\tIndex2
            |A\tATCG\tTCCG
            |A\tATCG\tTCCC
          DATA

  DATA3 = <<-DATA.gsub(/^\s+\|/, '')
            |#ID\tIndex1\tIndex2
            |A\tATCG\tTCCG
            |B\tATCG\tTCCG
          DATA

  def setup
    @file1 = Tempfile.new('sample_reader')
    @file2 = Tempfile.new('sample_reader')
    @file3 = Tempfile.new('sample_reader')

    File.open(@file1, 'w') { |ios| ios.puts DATA1 }
    File.open(@file2, 'w') { |ios| ios.puts DATA2 }
    File.open(@file3, 'w') { |ios| ios.puts DATA3 }
  end

  def teardown
    @file1.close
    @file1.unlink
    @file2.close
    @file2.unlink
    @file3.close
    @file3.unlink
  end

  test 'SampleReader#read returns correctly' do
    data = SampleReader.read(@file1, false, false)

    assert_equal(["A\tATCG\tTCCG", "B\tATCG\tTCCC"], data.map(&:to_s))
  end

  test 'SampleReader#read with index1 reverse_complemented returns correctly' do
    data = SampleReader.read(@file1, true, false)

    assert_equal(["A\tCGAT\tTCCG", "B\tCGAT\tTCCC"], data.map(&:to_s))
  end

  test 'SampleReader#read with index2 reverse_complemented returns correctly' do
    data = SampleReader.read(@file1, false, true)

    assert_equal(["A\tATCG\tCGGA", "B\tATCG\tGGGA"], data.map(&:to_s))
  end

  test 'SampleReader#read with both reverse_complemented returns correctly' do
    data = SampleReader.read(@file1, true, true)

    assert_equal(["A\tCGAT\tCGGA", "B\tCGAT\tGGGA"], data.map(&:to_s))
  end

  test 'SampleReader#read with non-unique sample IDs fails' do
    assert_raise(SampleReaderError) do
      capture_stderr { SampleReader.read(@file2, true, true) }
    end
  end

  test 'SampleReader#read with non-unique index combination fails' do
    assert_raise(SampleReaderError) do
      capture_stderr { SampleReader.read(@file3, true, true) }
    end
  end
end
