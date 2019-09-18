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

require 'flight_config'
require 'pathname'

require 'flight_metal/config'
require 'flight_metal/flight_config_utils'
require 'flight_metal/template_map'

require 'active_support/core_ext/hash'

module FlightMetal
  class Model
    include FlightConfig::Updater
    include FlightConfig::Deleter
    include FlightConfig::Globber
    include FlightConfig::Accessor

    include FlightConfigUtils
    include TemplateMap::PathAccessors

    def self.exists?(*a)
      File.exists? path(*a)
    end

    def self.join(*_a)
      raise NotImplementedError
    end

    def join(*rest)
      self.class.join(*__inputs__, *rest)
    end

    # The hash and eql? methods are required for uniq to work
    # To models are considered the same if they have the same inputs
    # This does not mean the data they store is the same as one could have
    # been modified or loaded at a different time
    def hash
      __inputs__.hash
    end

    def eql?(other)
      if self.class == other.class
        __inputs__.eql?(other.__inputs__)
      else
        false
      end
    end
  end
end

