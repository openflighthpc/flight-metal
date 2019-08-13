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
# For more information on flight-account, please visit:
# https://github.com/alces-software/flight-metal
#===============================================================================

module FlightMetal
  module CommandHelper
    module ClassMethods
      def command_require(*a)
        command_requires.push(*a)
      end

      def command_requires
        @command_requires ||= []
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def initialize(*_a)
      self.class.command_requires.each { |d| require d }
      super if defined?(super)
    end
  end

  ScopedCommand = Struct.new(:level, :raw_identifier) do
    include CommandHelper

    def model_class
      case level
      when :cluster, 'cluster'
        require 'flight_metal/models/cluster'
        Models::Cluster
      when :group, 'group'
        require 'flight_metal/models/group'
        Models::Group
      when :node, 'node'
        require 'flight_metal/models/node'
        Models::Node
      else
        raise InternalError, <<~ERROR.chomp
          Unrecognised command level #{level}
        ERROR
      end
    end

    def identifier
      raw = raw_identifier
      is_cluster = [:cluster, 'cluster'].include?(level)
      has_identifier = !(raw.nil? || raw.empty?)
      if is_cluster && has_identifier
        raise InternalError, <<~ERROR.chomp
          Can not use the identifier input within the cluster level
        ERROR
      elsif is_cluster || has_identifier
        raw
      else
        raise InternalError, <<~ERROR.chomp
          The #{level.to_s} identifier has not been set
        ERROR
      end
    end

    def read_model
      if model_class == Models::Cluster
        Models::Cluster.read(Config.cluster)
      else
        model_class.read(Config.cluster, identifier)
      end
    end
  end

  class Command
    include CommandHelper
  end
end
