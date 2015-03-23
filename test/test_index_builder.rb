#!/usr/bin/env ruby
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..')

require 'test/helper'

# Class for testing IndexBuilder.
class TestIndexBuilder < Test::Unit::TestCase
  DATA1 = <<-DATA.gsub(/^\s+\|/, '')
            |#ID\tIndex1\tIndex2
            |A\tAT\tCG
          DATA

  DATA2 = <<-DATA.gsub(/^\s+\|/, '')
            |#ID\tIndex1\tIndex2
            |A\tAT\tCG
            |B\tAA\tCC
          DATA

  def setup
    @file1 = Tempfile.new('sample_reader')
    @file2 = Tempfile.new('sample_reader')

    File.open(@file1, 'w') { |ios| ios.puts DATA1 }
    File.open(@file2, 'w') { |ios| ios.puts DATA2 }

    @samples1 = SampleReader.read(@file1, false, false)
    @samples2 = SampleReader.read(@file2, false, false)
  end

  def teardown
    @file1.close
    @file1.unlink
    @file2.close
    @file2.unlink
  end

  test 'IndexBuilder#build with mismatches_max 0 returns correctly' do
    ghash = IndexBuilder.build(@samples1, 0)
    size  = 0

    ghash.each { |_| size += 1 }

    assert_equal(1, size)
    assert_equal(0, ghash['ATCG'.hash])
  end

  test 'IndexBuilder#build with mismatches_max 1 returns correctly' do
    ghash = IndexBuilder.build(@samples1, 1)
    size  = 0
    keys  = %w(AT AA AC AG AT TT CT GT).product(%w(CA CT CC CG AG TG CG GG)).
            each_with_object([]) { |(a, b), m| m << a + b }.uniq

    ghash.each { |_| size += 1 }

    assert_equal(keys.size, size)
    keys.each { |key| assert_equal(0, ghash[key.hash]) }
  end

  test 'IndexBuilder#build with non-unique index combo fails' do
    assert_raise(IndexBuilderError) { IndexBuilder.build(@samples2, 1) }
  end
end
