#!/usr/bin/env ruby
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..')

require 'test/helper'

# Class for testing the DataIO class.
class TestDataIO < Test::Unit::TestCase
  SAMPLES      = <<-DATA.gsub(/^\s+\|/, '')
                   |#ID\tIndex1\tIndex2
                   |sample1\tAT\tCG
                 DATA

  FASTQ_INDEX1 = <<-DATA.gsub(/^\s+\|/, '')
                   |@index1
                   |at
                   |+
                   |II
                 DATA

  FASTQ_INDEX2 = <<-DATA.gsub(/^\s+\|/, '')
                   |@index2
                   |ct
                   |+
                   |II
                 DATA

  FASTQ_READ1  = <<-DATA.gsub(/^\s+\|/, '')
                   |@read1
                   |A
                   |+
                   |I
                 DATA

  FASTQ_READ2  = <<-DATA.gsub(/^\s+\|/, '')
                   |@read2
                   |G
                   |+
                   |I
                 DATA

  def setup
    @tmp_input  = Dir.mktmpdir('data_io_input')
    @tmp_output = Dir.mktmpdir('data_io_input')

    file_samples = File.join(@tmp_input, 'samples.txt')
    file_index1  = File.join(@tmp_input, 'x_S1_L001_I1_001x.fq')
    file_index2  = File.join(@tmp_input, 'x_S1_L001_I2_001x.fq')
    file_read1   = File.join(@tmp_input, 'x_S1_L001_R1_001x.fq')
    file_read2   = File.join(@tmp_input, 'x_S1_L001_R2_001x.fq')

    File.open(file_samples, 'w') { |ios| ios.puts SAMPLES }
    File.open(file_index1,  'w') { |ios| ios.puts FASTQ_INDEX1 }
    File.open(file_index2,  'w') { |ios| ios.puts FASTQ_INDEX2 }
    File.open(file_read1,   'w') { |ios| ios.puts FASTQ_READ1 }
    File.open(file_read2,   'w') { |ios| ios.puts FASTQ_READ2 }

    @samples     = SampleReader.read(file_samples, false, false)
    @fastq_files = [file_index1, file_index2, file_read1, file_read2]
  end

  def teardown
    FileUtils.rm_rf(@tmp_input)
    FileUtils.rm_rf(@tmp_output)
  end

  test 'DataIO#new with FASTQ files not matching _R1_ fails' do
    fastq_files = %w(x_S1_L001_R2_001x)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with FASTQ files not matching _R2_ fails' do
    fastq_files = %w(x_S1_L001_R1_001x)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with multiple FASTQ files matching _R1_ fails' do
    fastq_files = %w(_R1_ _R1_ x_S1_L001_R2_001x)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with multiple FASTQ files matching _R2_ fails' do
    fastq_files = %w(_R2_ _R2_ x_S1_L001_R1_001x)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with badly formatted SLR R1 string fails' do
    fastq_files = %w(x_S1_XXXX_R1_001x x_S1_L001_R2_001x)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with badly formatted SLR R2 string fails' do
    fastq_files = %w(x_S1_XXXX_R2_001x x_S1_L001_R1_001x)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with bad number of input files fails' do
    fastq_files = %w(x_S1_L001_R1_001x
                     x_S1_L001_R2_001x)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test '#open_input_files returns readable file handles' do
    data_io = DataIO.new(@samples, @fastq_files, false, @tmp_output)

    data_io.open_input_files do |ios|
      ios.each do |index1, index2, read1, read2|
        assert_equal('at', index1.seq)
        assert_equal('ct', index2.seq)
        assert_equal('A',  read1.seq)
        assert_equal('G',  read2.seq)
      end
    end
  end

  test '#open_output_files returns writable file handles' do
    data_io = DataIO.new(@samples, @fastq_files, false, @tmp_output)

    data_io.open_output_files do |ios|
      ios[0].first.puts 'foo 0'
      ios[0].last.puts 'bar 0'
      ios[1].first.puts 'foo 1'
      ios[1].last.puts 'bar 1'
    end

    files = Dir["#{@tmp_output}/*"]

    expected_names = ['sample1_S1_L001_R1_001.fastq',
                      'sample1_S1_L001_R2_001.fastq',
                      'Undetermined_S1_L001_R1_001.fastq',
                      'Undetermined_S1_L001_R2_001.fastq']

    result_names = files.map { |file| File.basename(file) }

    assert_equal(expected_names, result_names)

    expected_content = files.each_with_object([]) { |e, a| a << File.read(e) }

    result_content = ["foo 0\n", "bar 0\n", "foo 1\n", "bar 1\n"]

    assert_equal(expected_content, result_content)
  end
end
