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

# Class for IndexBuilder errors.
IndexBuilderError = Class.new(StandardError)

# Class containing methods for building an search index.
class IndexBuilder
  # Internal: Class method that build a search index from a given Array of
  # samples. The index consists of a Google Hash, which don't have Ruby's
  # garbage collection and therefore is much more efficient. The Hash keys
  # consists of index1 and index2 concatenated, and furthermore, if
  # mismatches_max is given index1, and index2 are permutated accordingly.
  # The Hash values are the sample number.
  #
  # samples - Array of samples (Sample objects with id, index1 and index2).
  #
  # Examples
  #
  #   IndexBuilder.build(samples)
  #     # => <Google Hash>
  #
  # Returns a Google Hash where the key is the index and the value is sample
  # number.
  def self.build(samples, mismatches_max)
    index_builder = new(samples, mismatches_max)
    index_hash    = index_builder.index_init
    index_builder.index_populate(index_hash)
  end

  # Internal: Constructor method for IndexBuilder object. The given Array of
  # samples and mismatches_max are saved as an instance variable.
  #
  # samples        - Array of Sample objects.
  # mismatches_max - Integer denoting the maximum number of misses allowed in
  #                  an index sequence.
  #
  # Examples
  #
  #   IndexBuilder.new(samples, 2)
  #     # => <IndexBuilder>
  #
  # Returns an IndexBuilder object.
  def initialize(samples, mismatches_max)
    @samples        = samples
    @mismatches_max = mismatches_max
  end

  # Internal: Method to initialize the index. If @mismatches_max is <= then
  # GoogleHashSparseLongToInt is used else GoogleHashDenseLongToInt due to
  # memory and performance.
  #
  # Returns a Google Hash.
  def index_init
    if @mismatches_max <= 1
      index_hash = GoogleHashSparseLongToInt.new
    else
      index_hash = GoogleHashDenseLongToInt.new
    end

    index_hash
  end

  # Internal: Method to populate the index.
  #
  # index_hash - Google Hash with initialized index.
  #
  # Returns a Google Hash.
  def index_populate(index_hash)
    @samples.each_with_index do |sample, i|
      index_list1 = permutate([sample.index1], @mismatches_max)
      index_list2 = permutate([sample.index2], @mismatches_max)

      index_list1.product(index_list2).each do |index1, index2|
        key = "#{index1}#{index2}".hash

        index_check_existing(index_hash, key, sample, index1, index2)

        index_hash[key] = i
      end
    end

    index_hash
  end

  private

  # Internal: Method to check if a index key already exists in the index, and
  # if so an exception is raised.
  #
  # index_hash - Google Hash with index
  # key        - Integer from Google Hash's #hash method
  # sample     - Sample object whos index to check.
  # index1     - String with index1 sequence.
  # index2     - String with index2 sequence.
  #
  # Returns nothing.
  def index_check_existing(index_hash, key, sample, index1, index2)
    return unless index_hash[key]

    fail IndexBuilderError, "Index combo of #{index1} and #{index2} already \
         exists for sample id: #{@samples[index_hash[key]].id} and #{sample.id}"
  end

  # Internal: Method that for each word in a given Array of word permutates
  # each word a given number (permuate) of times using a given alphabet, such
  # that an Array of words with all possible combinations is returned.
  #
  # list     - Array of words (Strings) to permutate.
  # permuate - Number of permutations (Integer).
  # alphabet - String with alphabet used for permutation.
  #
  # Examples
  #
  #   permutate(["AA"], 1, "ATCG")
  #   # => ["AA", "TA", "CA", "GA", "AA", "AT", "AC, "AG"]
  #
  # Returns an Array with permutated words (Strings).
  def permutate(list, permutations = 2, alphabet = 'ATCG')
    permutations.times do
      set = list.each_with_object(Set.new) { |e, a| a.add(e.to_sym) }

      list.each do |word|
        new_words = permutate_word(word, alphabet)
        new_words.map { |new_word| set.add(new_word.to_sym) }
      end

      list = set.map(&:to_s)
    end

    list
  end

  # Internal: Method that permutates a given word using a given alphabet, such
  # that an Array of words with all possible combinations is returned.
  #
  # word     - String with word to permutate.
  # alphabet - String with alphabet used for permutation.
  #
  # Examples
  #
  #   permutate("AA", "ATCG")
  #   # => ["AA", "TA", "CA", "GA", "AA", "AT", "AC, "AG"]
  #
  # Returns an Array with permutated words (Strings).
  def permutate_word(word, alphabet)
    new_words = []

    (0...word.size).each do |pos|
      alphabet.each_char do |char|
        new_words << "#{word[0...pos]}#{char}#{word[pos + 1..-1]}"
      end
    end

    new_words
  end
end
