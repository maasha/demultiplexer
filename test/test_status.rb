#!/usr/bin/env ruby
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..')

require 'test/helper'

# Class for testing the Status class.
class TestStatus < Test::Unit::TestCase
  SAMPLES = <<-DATA.gsub(/^\s+\|/, '')
              |#ID\tIndex1\tIndex2
              |A\tATCG\tTCCG
              |B\tATCG\tTCCC
            DATA

  EXPECTED = <<-YAML.gsub(/^\s+\|/, '')
               |---
               |:count: 0
               |:match: 0
               |:undetermined: 0
               |:undetermined_percent: 0.0
               |:index1_bad_mean: 0
               |:index2_bad_mean: 0
               |:index1_bad_min: 0
               |:index2_bad_min: 0
               |:sample_ids:
               |- A
               |- B
               |:index1:
               |- ATCG
               |:index2:
               |- TCCC
               |- TCCG
               |:time_elapsed: '00:00:00'
             YAML

  def setup
    @file_samples = Tempfile.new('samples')
    @file_status  = Tempfile.new('status')

    File.open(@file_samples, 'w') { |ios| ios.puts SAMPLES }

    @samples = SampleReader.read(@file_samples, false, false)
    @status  = Status.new(@samples)
  end

  def teardown
    @file_samples.close
    @file_samples.unlink
    @file_status.close
    @file_status.unlink
  end

  test 'Status#to_s returns correctly' do
    assert_equal(EXPECTED, @status.to_s)
  end

  test 'Status#save does so correctly' do
    @status.save(@file_status)

    assert_equal(EXPECTED, File.read(@file_status))
  end
end
