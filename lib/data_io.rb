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

# Class containing methods for reading and write FASTQ data files.
class DataIO
  def initialize(samples, fastq_files, compress, output_dir)
    @samples      = samples
    @compress     = compress
    @output_dir   = output_dir
    @suffix1      = extract_suffix(fastq_files.grep(/_R1_/).first)
    @suffix2      = extract_suffix(fastq_files.grep(/_R2_/).first)
    @input_files  = identify_input_files(fastq_files)
    @undetermined = @samples.size + 1
    @file_hash    = nil
  end

  # Method that extracts the Sample, Lane, Region information from a given file.
  #
  # file - String with file name.
  #
  # Examples
  #
  #   extract_suffix("Sample1_S1_L001_R1_001.fastq.gz")
  #   # => "_S1_L001_R1_001"
  #
  # Returns String with SLR info.
  def extract_suffix(file)
    if file =~ /.+(_S\d_L\d{3}_R[12]_\d{3}).+$/
      slr = Regexp.last_match(1)
    else
      fail "Unable to parse file SLR from: #{file}"
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
    @file_ios = []

    @input_files.each do |input_file|
      @file_ios << BioPieces::Fastq.open(input_file)
    end

    yield self
  ensure
    close_input_files
  end

  # Method that closes open input files.
  #
  # Returns nothing.
  def close_input_files
    @file_ios.map(&:close)
  end

  # Method that reads a Seq entry from each of the file handles in the
  # @file_ios Array. Iteration stops when no more Seq entries are found.
  #
  # Yields an Array with 4 Seq objects.
  #
  # Returns nothing
  def each
    loop do
      entries = @file_ios.each_with_object([]) { |e, a| a << e.next_entry }

      break if entries.compact.size != 4

      yield entries
    end
  end

  # Method that opens the output files for writing.
  #
  # Yeilds a Hash with an incrementing index as keys, and a tuple of file
  # handles as values.
  def open_output_files
    @file_hash = {}
    comp       = @compress

    @file_hash.merge!(open_output_files_samples(comp))
    @file_hash.merge!(open_output_files_undet(comp))

    yield self
  ensure
    close_output_files
  end

  def close_output_files
    @file_hash.each_value { |value| value.map(&:close) }
  end

  # Getter method that returns a tuple of file handles from @file_hash when
  # given a key.
  #
  # key - Key used to lookup
  #
  # Returns Array with a tuple of IO objects.
  def [](key)
    @file_hash[key]
  end

  # Method that opens the sample output files for writing.
  #
  # comp - Symbol with type of output compression.
  #
  # Returns a Hash with an incrementing index as keys, and a tuple of file
  # handles as values.
  def open_output_files_samples(comp)
    file_hash = {}

    @samples.each_with_index do |sample, i|
      file_forward = File.join(@output_dir, "#{sample.id}#{@suffix1}")
      file_reverse = File.join(@output_dir, "#{sample.id}#{@suffix2}")
      io_forward   = BioPieces::Fastq.open(file_forward, 'w', compress: comp)
      io_reverse   = BioPieces::Fastq.open(file_reverse, 'w', compress: comp)
      file_hash[i] = [io_forward, io_reverse]
    end

    file_hash
  end

  # Method that opens the undertermined output files for writing.
  #
  # comp - Symbol with type of output compression.
  #
  # Returns a Hash with an incrementing index as keys, and a tuple of file
  # handles as values.
  def open_output_files_undet(comp)
    file_hash    = {}
    file_forward = File.join(@output_dir, "Undetermined#{@suffix1}")
    file_reverse = File.join(@output_dir, "Undetermined#{@suffix2}")
    io_forward   = BioPieces::Fastq.open(file_forward, 'w', compress: comp)
    io_reverse   = BioPieces::Fastq.open(file_reverse, 'w', compress: comp)
    file_hash[@undetermined] = [io_forward, io_reverse]

    file_hash
  end
end
