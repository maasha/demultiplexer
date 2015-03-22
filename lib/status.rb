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

# Class containing methods to records demultiplexing status.
class Status
  attr_accessor :count, :match, :undetermined, :index1_bad_mean,
                :index2_bad_mean, :index1_bad_min, :index2_bad_min
  # Method to initialize a Status object, which contains the following instance
  # variables initialized to 0:
  #
  #   @count           - Number or reads.
  #   @match           - Number of reads found in index.
  #   @undetermined    - Number of reads not found in index.
  #   @index1_bad_mean - Number of reads dropped due to bad mean in index1.
  #   @index2_bad_mean - Number of reads dropped due to bad mean in index2.
  #   @index1_bad_min  - Number of reads dropped due to bad min in index1.
  #   @index2_bad_min  - Number of reads dropped due to bad min in index2.
  #
  # Examples
  #
  #   Status.new
  #   # => <Status>
  #
  # Returns a Status object.
  def initialize
    @count           = 0
    @match           = 0
    @undetermined    = 0
    @index1_bad_mean = 0
    @index2_bad_mean = 0
    @index1_bad_min  = 0
    @index2_bad_min  = 0
    @time_start      = Time.now
  end

  # Method to format a String from a Status object. This is done by adding the
  # relevant instance variables to a Hash and return this as an YAML String.
  #
  # Returns a YAML String.
  def to_s
    { count:                @count,
      match:                @match,
      undetermined:         @undetermined,
      undetermined_percent: undetermined_percent,
      index1_bad_mean:      @index1_bad_mean,
      index2_bad_mean:      @index2_bad_mean,
      index1_bad_min:       @index1_bad_min,
      index2_bad_min:       @index2_bad_min,
      time:                 time }.to_yaml
  end

  # Method that calculate the percentage of undetermined reads.
  #
  # Returns a Float with the percentage of undetermined reads.
  def undetermined_percent
    (100 * @undetermined / @count.to_f).round(1)
  end

  # Method that calculates the elapsed time and formats a nice Time String.
  #
  # Returns String with elapsed time.
  def time
    time_elapsed = Time.now - @time_start
    (Time.mktime(0) + time_elapsed).strftime('%H:%M:%S')
  end

  # Method to save stats to the log file 'Demultiplex.log' in the output
  # directory.
  #
  # Returns nothing.
  def save(file)
    @stats[:sample_id] = @samples.map(&:id)

    @stats[:index1] = uniq_index1
    @stats[:index2] = uniq_index2

    File.open(file, 'w') do |ios|
      ios.puts @status
    end
  end
end
