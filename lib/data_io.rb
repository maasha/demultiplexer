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

# Error class for all errors to do with DataIO.
DataIOError = Class.new(StandardError)

# Class containing methods for reading and write FASTQ data files.
class DataIO
  # Internal: Constructor method for DataIO objects.
  #
  # samples     - Array with Sample objects consisting id, index1 and index2
  # fastq_files - Array of Strings with FASTQ file names of multiplexed data.
  # compress    - Symbol indicating if output data should be compressed with
  #               either gzip or bzip2.
  # output_dir  - String with path of output directory.
  #
  # Returns DataIO object.
  def initialize(samples, fastq_files, compress, output_dir)
    @samples         = samples
    @compress        = compress
    @output_dir      = output_dir
    @suffix1         = extract_suffix(fastq_files, '_R1_')
    @suffix2         = extract_suffix(fastq_files, '_R2_')
    @input_files     = identify_input_files(fastq_files)
    @undetermined    = @samples.size + 1
    @output_file_ios = nil
  end

  # Method that extracts the Sample, Lane, Region information from given files.
  #
  # files   - Array with FASTQ file names as Strings.
  # pattern - String with pattern to use for matching file names.
  #
  # Examples
  #
  #   extract_suffix("Sample1_S1_L001_R1_001.fastq.gz", "_R1_")
  #   # => "_S1_L001_R1_001"
  #
  # Returns String with SLR info.
  # Raises unless pattern match exactly 1 file.
  # Raises unless SLR info can be parsed.
  def extract_suffix(files, pattern)
    hits = files.grep(Regexp.new(pattern))

    unless hits.size == 1
      fail DataIOError, "Expecting exactly 1 hit but got: #{hits.join(', ')}"
    end

    if hits.first =~ /.+(_S\d_L\d{3}_R[12]_\d{3}).+$/
      slr = Regexp.last_match(1)
    else
      fail DataIOError, "Unable to parse file SLR from: #{hits.first}"
    end

    append_suffix(slr)
  end

  # Method that appends a file suffix to a given Sample, Lane, Region
  # information String based on the @options[:compress] option. The
  # file suffix can be either ".fastq.gz", ".fastq.bz2", or ".fastq".
  #
  # slr - String Sample, Lane, Region information.
  #
  # Examples
  #
  #   append_suffix("_S1_L001_R1_001")
  #   # => "_S1_L001_R1_001.fastq.gz"
  #
  # Returns String with SLR info and file suffix.
  def append_suffix(slr)
    case @compress
    when /gzip/
      slr << '.fastq.gz'
    when /bzip2/
      slr << '.fastq.bz2'
    else
      slr << '.fastq'
    end

    slr
  end

  # Method identify the different input files from a given Array of FASTQ files.
  # The forward index file contains a _I1_, the reverse index file contains a
  # _I2_, the forward read file contains a _R1_ and finally, the reverse read
  # file contain a _R2_.
  #
  # fastq_files - Array with FASTQ files (Strings).
  #
  # Returns an Array with input files (Strings).
  def identify_input_files(fastq_files)
    input_files = []

    input_files << fastq_files.grep(/_I1_/).first
    input_files << fastq_files.grep(/_I2_/).first
    input_files << fastq_files.grep(/_R1_/).first
    input_files << fastq_files.grep(/_R2_/).first

    input_files
  end

  # Method that opens the @input_files for reading.
  #
  # input_files - Array with input file paths.
  #
  # Returns an Array with IO objects (file handles).
  def open_input_files
    @input_file_ios = []

    @input_files.each do |input_file|
      @input_file_ios << BioPieces::Fastq.open(input_file)
    end

    yield self
  ensure
    close_input_files
  end

  # Method that closes open input files.
  #
  # Returns nothing.
  def close_input_files
    @input_file_ios.map(&:close)
  end

  # Method that reads a Seq entry from each of the file handles in the
  # @input_file_ios Array. Iteration stops when no more Seq entries are found.
  #
  # Yields an Array with 4 Seq objects.
  #
  # Returns nothing
  def each
    loop do
      entries = @input_file_ios.each_with_object([]) do |e, a|
        a << e.next_entry
      end

      break if entries.compact.size != 4

      yield entries
    end
  end

  # Method that opens the output files for writing.
  #
  # Yeilds a Hash with an incrementing index as keys, and a tuple of file
  # handles as values.
  def open_output_files
    @output_file_ios = {}
    comp             = @compress

    @output_file_ios.merge!(open_output_files_samples(comp))
    @output_file_ios.merge!(open_output_files_undet(comp))

    yield self
  ensure
    close_output_files
  end

  def close_output_files
    @output_file_ios.each_value { |value| value.map(&:close) }
  end

  # Getter method that returns a tuple of file handles from @output_file_ios
  # when given a key.
  #
  # key - Key used to lookup
  #
  # Returns Array with a tuple of IO objects.
  def [](key)
    @output_file_ios[key]
  end

  # Method that opens the sample output files for writing.
  #
  # comp - Symbol with type of output compression.
  #
  # Returns a Hash with an incrementing index as keys, and a tuple of file
  # handles as values.
  def open_output_files_samples(comp)
    output_file_ios = {}

    @samples.each_with_index do |sample, i|
      file_forward = File.join(@output_dir, "#{sample.id}#{@suffix1}")
      file_reverse = File.join(@output_dir, "#{sample.id}#{@suffix2}")
      io_forward   = BioPieces::Fastq.open(file_forward, 'w', compress: comp)
      io_reverse   = BioPieces::Fastq.open(file_reverse, 'w', compress: comp)
      output_file_ios[i] = [io_forward, io_reverse]
    end

    output_file_ios
  end

  # Method that opens the undertermined output files for writing.
  #
  # comp - Symbol with type of output compression.
  #
  # Returns a Hash with an incrementing index as keys, and a tuple of file
  # handles as values.
  def open_output_files_undet(comp)
    output_file_ios    = {}
    file_forward = File.join(@output_dir, "Undetermined#{@suffix1}")
    file_reverse = File.join(@output_dir, "Undetermined#{@suffix2}")
    io_forward   = BioPieces::Fastq.open(file_forward, 'w', compress: comp)
    io_reverse   = BioPieces::Fastq.open(file_reverse, 'w', compress: comp)
    output_file_ios[@undetermined] = [io_forward, io_reverse]

    output_file_ios
  end
end
