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

require 'csv'
require 'set'
require 'biopieces'

# Class for all SampleReader errors.
SampleReaderError = Class.new(StandardError)

# Class containing methods for reading and checking sample information.
class SampleReader
  # Public: Class method that reads sample information from a samples file,
  # which consists of ASCII text in three tab separated columns: The first
  # column is the sample_id, the second column is index1 and the third column is
  # index2.
  #
  # If revcomp1 or revcomp2 is set then index1 and index2 are
  # reverse-complemented accordingly.
  #
  # file     - String with path to sample file.
  # revcomp1 - Flag indicating that index1 should be reverse-complemented.
  # revcomp2 - Flag indicating that index2 should be reverse-complemented.
  #
  # Examples
  #
  #   SampleReader.read("samples.txt", false, false)
  #   # => [<Sample>, <Sample>, <Sample> ...]
  #
  # Returns an Array of Sample objects.
  def self.read(file, revcomp1, revcomp2)
    sample_reader = new(revcomp1, revcomp2)
    sample_reader.samples_parse(file)
  end

  # Constructor method for SampleReader object. The given revcomp1 and revcomp2
  # flags are stored as instance variables.
  #
  # revcomp1 - Flag indicating that index1 should be reverse-complemented.
  # revcomp2 - Flag indicating that index2 should be reverse-complemented.
  #
  # Examples
  #
  #   SampleReader.new(false, false)
  #   # => <SampleReader>
  #
  # Returns SampleReader object.
  def initialize(revcomp1, revcomp2)
    @revcomp1 = revcomp1
    @revcomp2 = revcomp2
  end

  # Method that reads sample information from a samples file, which consists
  # of ASCII text in three tab separated columns: The first column is the
  # sample_id, the second column is index1 and the third column is index2.
  #
  # file - String with path to sample file.
  #
  # Examples
  #
  #   samples_parse("samples.txt")
  #   # => [<Sample>, <Sample>, <Sample> ...]
  #
  # Returns an Array of Sample objects.
  def samples_parse(file)
    samples = samples_read(file)
    samples_reverse_complement(samples)
    errors = []
    errors.push(*samples_check_index_combo(samples))
    errors.push(*samples_check_uniq_id(samples))

    unless errors.empty?
      warn errors
      fail SampleReaderError, 'errors found in sample file.'
    end

    samples
  end

  private

  # Method that reads sample information form a samples file, which consists
  # of ASCII text in three tab separated columns: The first column is the
  # sample_id, the second column is index1 and the third column is index2.
  #
  # If @options[:revcomp_index1] or @options[:revcomp_index2] is set then
  # index1 and index2 are reverse-complemented accordingly.
  #
  # file - String with path to sample file.
  #
  # Examples
  #
  #   samples_read("samples.txt")
  #   # => [<Sample>, <Sample>, <Sample> ...]
  #
  # Returns an Array of Sample objects.
  def samples_read(file)
    samples = []

    CSV.read(file, col_sep: "\t").each do |id, index1, index2|
      next if id[0] == '#'

      samples << Sample.new(id, index1, index2)
    end

    samples
  end

  # Method that iterates over the a given Array of sample Objects, and if
  # @options[:revcomp_index1] or @options[:revcomp_index2] is set then
  # index1 and index2 are reverse-complemented accordingly.
  #
  # samples - Array of Sample objects.
  #
  # Returns nothing.
  def samples_reverse_complement(samples)
    samples.each do |sample|
      sample.index1 = index_reverse_complement(sample.index1) if @revcomp1
      sample.index2 = index_reverse_complement(sample.index2) if @revcomp2
    end
  end

  # Method that reverse-complements a given index sequence.
  #
  # index - Index String.
  #
  # Returns reverse-complemented index String.
  def index_reverse_complement(index)
    BioPieces::Seq.new(seq: index, type: :dna).reverse.complement.seq
  end

  # Method that iterates over the a given Array of sample Objects, and if
  # the combination of index1 and index2 is non-unique an error is pushed
  # on an error Array.
  #
  # samples - Array of Sample objects.
  #
  # Returns an Array of found errors.
  def samples_check_index_combo(samples)
    errors = []
    lookup = {}

    samples.each do |sample|
      if (id2 = lookup["#{sample.index1}#{sample.index2}"])
        errors << ['Samples with same index combo', sample.id, id2].join("\t")
      else
        lookup["#{sample.index1}#{sample.index2}"] = sample.id
      end
    end

    errors
  end

  # Method that iterates over the a given Array of sample Objects, and if
  # a sample id is non-unique an error is pushed  on an error Array.
  #
  # samples - Array of Sample objects.
  #
  # Returns an Array of found errors.
  def samples_check_uniq_id(samples)
    errors = []
    lookup = Set.new

    samples.each do |sample|
      if lookup.include? sample.id
        errors << ['Non-unique sample id', sample.id].join("\t")
      end

      lookup << sample.id
    end

    errors
  end

  # Struct for holding sample information.
  #
  # id     - Sample id.
  # index1 - Index1 sequence.
  # index2 - Index2 sequence.
  #
  # Examples
  #
  #   Sample.new("test1", "atcg", "gcta")
  #     # => <Sample>
  #
  # Returns Sample object.
  Sample = Struct.new(:id, :index1, :index2) do
    # Method that returns a String representaion of a Sample object.
    #
    # Examples
    #
    #   Sample.to_s
    #     # => "test\tATCG\tTCGA"
    #
    # Returns a String with the values joined by "\t".
    def to_s
      [id, index1, index2].join("\t")
    end
  end
end
