#!/usr/bin/env ruby
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..')

require 'test/helper'

# Class for testing Demultiplexer.
class TestDemultiplexer < Test::Unit::TestCase
  SAMPLES      = <<-DATA.gsub(/^\s+\|/, '')
                   |#ID\tIndex1\tIndex2
                   |sample1\taT\tCg
                 DATA

  FASTQ_INDEX1 = <<-DATA.gsub(/^\s+\|/, '')
                   |@index1
                   |Aa
                   |+
                   |II
                 DATA

  FASTQ_INDEX2 = <<-DATA.gsub(/^\s+\|/, '')
                   |@index2
                   |cC
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

  STATUS1      = <<-YAML.gsub(/^\s+\|/, '')
                 |---
                 |:count: 2
                 |:match: 0
                 |:undetermined: 2
                 |:undetermined_percent: 100.0
                 |:index1_bad_mean: 0
                 |:index2_bad_mean: 0
                 |:index1_bad_min: 0
                 |:index2_bad_min: 0
                 |:sample_ids:
                 |- sample1
                 |:index1:
                 |- AT
                 |:index2:
                 |- CG
                 |:time_elapsed: '00:00:00'
               YAML

  STATUS2      = <<-YAML.gsub(/^\s+\|/, '')
                 |---
                 |:count: 2
                 |:match: 2
                 |:undetermined: 0
                 |:undetermined_percent: 0.0
                 |:index1_bad_mean: 0
                 |:index2_bad_mean: 0
                 |:index1_bad_min: 0
                 |:index2_bad_min: 0
                 |:sample_ids:
                 |- sample1
                 |:index1:
                 |- AT
                 |:index2:
                 |- CG
                 |:time_elapsed: '00:00:00'
               YAML

  def setup
    @tmp_input  = Dir.mktmpdir('data_io_input')
    @tmp_output = Dir.mktmpdir('data_io_input')

    @file_samples = File.join(@tmp_input, 'samples.txt')
    file_index1   = File.join(@tmp_input, 'x_S1_L001_I1_001x.fq')
    file_index2   = File.join(@tmp_input, 'x_S1_L001_I2_001x.fq')
    file_read1    = File.join(@tmp_input, 'x_S1_L001_R1_001x.fq')
    file_read2    = File.join(@tmp_input, 'x_S1_L001_R2_001x.fq')

    File.open(@file_samples, 'w') { |ios| ios.puts SAMPLES }
    File.open(file_index1,   'w') { |ios| ios.puts FASTQ_INDEX1 }
    File.open(file_index2,   'w') { |ios| ios.puts FASTQ_INDEX2 }
    File.open(file_read1,    'w') { |ios| ios.puts FASTQ_READ1 }
    File.open(file_read2,    'w') { |ios| ios.puts FASTQ_READ2 }

    @fastq_files = [file_index1, file_index2, file_read1, file_read2]
  end

  def teardown
    FileUtils.rm_rf(@tmp_input)
    FileUtils.rm_rf(@tmp_output)
  end

  test '#run produces the correct output files' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    output_dir: @tmp_output)

    result = Dir["#{@tmp_output}/*"].map { |file| File.basename file }

    expected = ['Demultiplex.log',
                'sample1_S1_L001_R1_001.fastq',
                'sample1_S1_L001_R2_001.fastq',
                'Undetermined_S1_L001_R1_001.fastq',
                'Undetermined_S1_L001_R2_001.fastq']

    assert_equal(expected, result)
  end

  test '#run produces OK log file with mismatches_max: 0' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    mismatches_max: 0, output_dir: @tmp_output)

    result = File.read(File.join(@tmp_output, 'Demultiplex.log'))

    assert_equal(STATUS1, result)
  end

  test '#run produces OK R1 file with mismatches_max: 0' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    mismatches_max: 0, output_dir: @tmp_output)

    result = File.read(File.join(@tmp_output, 'sample1_S1_L001_R1_001.fastq'))

    assert_equal('', result)
  end

  test '#run produces OK R2 file with mismatches_max: 0' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    mismatches_max: 0, output_dir: @tmp_output)

    result = File.read(File.join(@tmp_output, 'sample1_S1_L001_R2_001.fastq'))

    assert_equal('', result)
  end

  test '#run produces OK Undetermined R1 file with mismatches_max: 0' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    mismatches_max: 0, output_dir: @tmp_output)

    file   = File.join(@tmp_output, 'Undetermined_S1_L001_R1_001.fastq')
    result = File.read(file)

    assert_equal("@read1 Aa\nA\n+\nI\n", result)
  end

  test '#run produces OK Undetermined R2 file with mismatches_max: 0' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    mismatches_max: 0, output_dir: @tmp_output)

    file   = File.join(@tmp_output, 'Undetermined_S1_L001_R2_001.fastq')
    result = File.read(file)

    assert_equal("@read2 cC\nG\n+\nI\n", result)
  end

  test '#run produces OK log with mismatches_max: 1' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    mismatches_max: 1, output_dir: @tmp_output)

    result = File.read(File.join(@tmp_output, 'Demultiplex.log'))

    assert_equal(STATUS2, result)
  end

  test '#run produces OK R1 file with mismatches_max: 1' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    mismatches_max: 1, output_dir: @tmp_output)

    result = File.read(File.join(@tmp_output, 'sample1_S1_L001_R1_001.fastq'))

    assert_equal("@read1\nA\n+\nI\n", result)
  end

  test '#run produces OK R2 file with mismatches_max: 1' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    mismatches_max: 1, output_dir: @tmp_output)

    result = File.read(File.join(@tmp_output, 'sample1_S1_L001_R2_001.fastq'))

    assert_equal("@read2\nG\n+\nI\n", result)
  end

  test '#run produces OK Undetermined R1 file with mismatches_max: 1' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    mismatches_max: 1, output_dir: @tmp_output)

    file   = File.join(@tmp_output, 'Undetermined_S1_L001_R1_001.fastq')
    result = File.read(file)

    assert_equal('', result)
  end

  test '#run produces OK Undetermined R2 file with mismatches_max: 1' do
    Demultiplexer.run(@fastq_files, samples_file: @file_samples,
                                    mismatches_max: 1, output_dir: @tmp_output)

    file   = File.join(@tmp_output, 'Undetermined_S1_L001_R2_001.fastq')
    result = File.read(file)

    assert_equal('', result)
  end
end
