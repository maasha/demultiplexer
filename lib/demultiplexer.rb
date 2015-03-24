# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #
#                                                                              #
# Copyright (C) 2014-2015 Martin Asser Hansen (mail@maasha.dk).                #
#                                                                              #
# This program is free software; you can redistribute it and/or                #
# modify it under the terms of the GNU General Public License                  #
# as published by the Free Software Foundation; either version 2               #
# of the License, or (at your option) any later version.                       #
#                                                                              #
# This program is distributed in the hope that it will be useful,              #
# but WITHOUT ANY WARRANTY; without even the implied warranty of               #
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                #
# GNU General Public License for more details.                                 #
#                                                                              #
# You should have received a copy of the GNU General Public License            #
# along with this program; if not, write to the Free Software                  #
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,    #
# USA.                                                                         #
#                                                                              #
# http://www.gnu.org/copyleft/gpl.html                                         #
#                                                                              #
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< #

require 'google_hash'
require 'status'
require 'sample_reader'
require 'index_builder'
require 'data_io'
require 'screen'

# Class containing methods for demultiplexing MiSeq sequences.
class Demultiplexer
  DEFAULT = { verbose:        false,
              mismatches_max: 0,
              revcomp_index1: false,
              revcomp_index2: false,
              scores_min:     16,
              scores_mean:    16
            }

  attr_reader :status

  # Public: Class method to run demultiplexing of MiSeq sequences.
  #
  # fastq_files - Array with paths to FASTQ files.
  # options     - Options Hash.
  #               :verbose        - Verbose flag (default: false).
  #               :mismatches_max - Integer value indicating max mismatches
  #                                 (default: 0).
  #               :samples_file   - String with path to samples file.
  #               :revcomp_index1 - Flag indicating that index1 should be
  #                                 reverse-complemented (default: false).
  #               :revcomp_index2 - Flag indicating that index2 should be
  #                                 reverse-complemented (default: false).
  #               :output_dir     - String with output directory (optional).
  #               :scores_min     - An Integer representing the Phred score
  #                                 minimum, such that a reads is dropped if a
  #                                 single position in the index contain a
  #                                 score below this value (default: 16).
  #               :scores_mean=>  - An Integer representing the mean Phread
  #                                 score, such that a read is dropped if the
  #                                 mean quality score is below this value
  #                                 (default: 16).
  #
  # Examples
  #
  #   Demultiplexer.run(['I1.fq', 'I2.fq', 'R1.fq', 'R2.fq'], \
  #     samples_file: 'samples.txt')
  #   # => <Demultiplexer>
  #
  # Returns Demultiplexer object
  def self.run(fastq_files, options)
    options       = DEFAULT.merge(options)
    log_file      = File.join(options[:output_dir], 'Demultiplex.log')
    demultiplexer = new(fastq_files, options)
    Screen.clear if options[:verbose]
    demultiplexer.demultiplex
    puts demultiplexer.status if options[:verbose]
    demultiplexer.status.save(log_file)
  end

  # Internal: Constructor method for Demultiplexer object.
  #
  # fastq_files - Array with paths to FASTQ files.
  # options     - Options Hash.
  #               :verbose        - Verbose flag (default: false).
  #               :mismatches_max - Integer value indicating max mismatches
  #                                 (default: 0).
  #               :samples_file   - String with path to samples file.
  #               :revcomp_index1 - Flag indicating that index1 should be
  #                                 reverse-complemented (default: false).
  #               :revcomp_index2 - Flag indicating that index2 should be
  #                                 reverse-complemented (default: false).
  #               :output_dir     - String with output directory (optional).
  #               :scores_min     - An Integer representing the Phred score
  #                                 minimum, such that a reads is dropped if a
  #                                 single position in the index contain a
  #                                 score below this value (default: 16).
  #               :scores_mean=>  - An Integer representing the mean Phread
  #                                 score, such that a read is dropped if the
  #                                 mean quality score is below this value
  #                                 (default: 16).
  #
  # Returns Demultiplexer object
  def initialize(fastq_files, options)
    @options      = options
    @samples      = SampleReader.read(options[:samples_file],
                                      options[:revcomp_index1],
                                      options[:revcomp_index2])
    @undetermined = @samples.size
    @index_hash   = IndexBuilder.build(@samples, options[:mismatches_max])
    @data_io      = DataIO.new(@samples, fastq_files, options[:compress],
                               options[:output_dir])
    @status       = Status.new(@samples)
  end

  # Internal: Method to demultiplex reads according the index. This is done by
  # simultaniously read-opening all input files (forward and reverse index
  # files and forward and reverse read files) and read one entry from each.
  # Such four entries we call a set of entries. If the quality scores from
  # either index1 or index2 fails the criteria for mean and min required
  # quality the set is skipped. In the combined indexes are found in the
  # search index, then the reads are writting to files according to the sample
  # information in the search index. If the combined indexes are not found,
  # then the reads have their names appended with the index sequences and the
  # reads are written to the Undertermined files.
  #
  # Returns nothing.
  def demultiplex
    @data_io.open_input_files do |ios_in|
      @data_io.open_output_files do |ios_out|
        ios_in.each do |index1, index2, read1, read2|
          @status.count += 2
          if @options[:verbose] &&  (@status.count % 1_000) == 0
            Screen.reset
            puts @status
          end

          next unless index_qual_ok?(index1, index2)

          match_index(ios_out, index1, index2, read1, read2)

          # break if @status.count == 100_000
        end
      end
    end
  end

  private

  # Internal: Method that matches the combined index1 and index2 sequences
  # against the search index. In case of a match the reads are written to file
  # according to the information in the search index, otherwise the reads will
  # have thier names appended with the index sequences and they will be written
  # to the Undetermined files.
  #
  # ios_out - DataIO object with an accessor method for file output handles.
  # index1  - Seq object with index1.
  # index2  - Seq object with index2.
  # read1   - Seq object with read1.
  # read2   - Seq object with read2.
  #
  # Returns nothing.
  def match_index(ios_out, index1, index2, read1, read2)
    key = "#{index1.seq.upcase}#{index2.seq.upcase}".hash

    if (sample_id = @index_hash[key])
      write_match(ios_out, sample_id, read1, read2)
    else
      write_undetermined(ios_out, index1, index2, read1, read2)
    end
  end

  # Internal: Method that writes a index match to file according to the
  # information in the search index.
  #
  # ios_out - DataIO object with an accessor method for file output handles.
  # read1   - Seq object with read1.
  # read2   - Seq object with read2.
  #
  # Returns nothing.
  def write_match(ios_out, sample_id, read1, read2)
    @status.match += 2
    io_forward, io_reverse = ios_out[sample_id]

    io_forward.puts read1.to_fastq
    io_reverse.puts read2.to_fastq
  end

  # Internal: Method that appends the read names with the index sequences and
  # writes the reads to the Undetermined files.
  #
  # ios_out - DataIO object with an accessor method for file output handles.
  # index1  - Seq object with index1.
  # index2  - Seq object with index2.
  # read1   - Seq object with read1.
  # read2   - Seq object with read2.
  #
  # Returns nothing.
  def write_undetermined(ios_out, index1, index2, read1, read2)
    @status.undetermined += 2
    read1.seq_name = "#{read1.seq_name} #{index1.seq}"
    read2.seq_name = "#{read2.seq_name} #{index2.seq}"

    io_forward, io_reverse = ios_out[@undetermined]
    io_forward.puts read1.to_fastq
    io_reverse.puts read2.to_fastq
  end

  # Internal: Method to check the quality scores of the given indexes.
  # If the mean score is higher than @options[:scores_mean] or
  # if the min score is higher than @options[:scores_min] then
  # the indexes are OK.
  #
  # index1 - Index1 Seq object.
  # index2 - Index2 Seq object.
  #
  # Returns true if quality OK, else false.
  def index_qual_ok?(index1, index2)
    index_qual_mean_ok?(index1, index2) &&
      index_qual_min_ok?(index1, index2)
  end

  # Internal: Method to check the mean quality scores of the given indexes.
  # If the mean score is higher than @options[:scores_mean] the
  # indexes are OK.
  #
  # index1 - Index1 Seq object.
  # index2 - Index2 Seq object.
  #
  # Returns true if quality mean OK, else false.
  def index_qual_mean_ok?(index1, index2)
    if index1.scores_mean < @options[:scores_mean]
      @status.index1_bad_mean += 2
      return false
    elsif index2.scores_mean < @options[:scores_mean]
      @status.index2_bad_mean += 2
      return false
    end

    true
  end

  # Internal: Method to check the min quality scores of the given indexes.
  # If the min score is higher than @options[:scores_min] the
  # indexes are OK.
  #
  # index1 - Index1 Seq object.
  # index2 - Index2 Seq object.
  #
  # Returns true if quality min OK, else false.
  def index_qual_min_ok?(index1, index2)
    if index1.scores_min < @options[:scores_min]
      @status.index1_bad_min += 2
      return false
    elsif index2.scores_min < @options[:scores_min]
      @status.index2_bad_min += 2
      return false
    end

    true
  end
end
