# frozen_string_literal: true

#==============================================================================
# Copyright (C) 2019-present Alces Flight Ltd.
#
# This file is part of flight-metal.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# This project is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with this project. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on flight-metal, please visit:
# https://github.com/alces-software/flight-metal
#===============================================================================

require 'flight_metal/model'

module FlightMetal
  class Index < Model
    # NOTE: For the time being, all indices must be .yaml b/c TTY::Config is used
    # to write an empty file
    # def path(....)
    #   super
    # end

    def self.glob_read(*a)
      indices = super
      indices.reject do |index|
        next if index.valid?
        File.rm_f index.path
        true
      end
    end

    # Spoof the content data so that it doesn't load the file. Instead it will
    # confirm the index is valid on `read`
    def __data__
      @__data__ ||= begin
        if __read_mode__ && !valid?
          File.rm_f path
          raise InvalidModel, <<~ERROR.chomp
            Could not load index as it is invalid
          ERROR
        end
        TTY::Config.new
      end
    end

    def valid?
      raise NotImplementedError
    end
  end
end
