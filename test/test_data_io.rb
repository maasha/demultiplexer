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
                   |IIII
                 DATA

  FASTQ_INDEX2 = <<-DATA.gsub(/^\s+\|/, '')
                   |@index2
                   |ct
                   |+
                   |IIII
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
    file_index1  = File.join(@tmp_input, 'index1.fq')
    file_index2  = File.join(@tmp_input, 'index2.fq')
    file_read1   = File.join(@tmp_input, 'read1.fq')
    file_read2   = File.join(@tmp_input, 'read2.fq')

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
    fastq_files = %w(_S1_L001_R2_001)
 
    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with FASTQ files not matching _R2_ fails' do
    fastq_files = %w(_S1_L001_R1_001)
 
    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with multiple FASTQ files matching _R1_ fails' do
    fastq_files = %w(_R1_ _R1_ _S1_L001_R2_001)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with multiple FASTQ files matching _R2_ fails' do
    fastq_files = %w(_R2_ _R2_ _S1_L001_R1_001)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with badly formatted SLR R1 string fails' do
    fastq_files = %w(_S1_XXXX_R1_001 _S1_L001_R2_001)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end

  test 'DataIO#new with badly formatted SLR R2 string fails' do
    fastq_files = %w(_S1_XXXX_R2_001 _S1_L001_R1_001)

    assert_raise(DataIOError) do
      DataIO.new(@samples, fastq_files, false, @tmp_output)
    end
  end
end
