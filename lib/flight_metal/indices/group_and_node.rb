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

require 'flight_metal/index'

module FlightMetal
  module Indices
    class GroupAndNode < Index
      def self.path(cluster, group, node, type)
        Models::Cluster.cache_join(cluster, "#{type}-groups", group, "#{node}.yaml")
      end
      define_input_methods_from_path_parameters

      def read_group
        Models::Group.read(cluster, group, registry: __registry__)
      end

      def read_node
        Models::Node.read(cluster, node, registry: __registry__)
      end

      def valid?
        case type.to_sym
        when :primary
          read_node.primary_group == group
        when :other
          read_node.other_groups.include?(group)
        else
          false
        end
      end
    end
  end
end

require 'flight_metal/models/node'
require 'flight_metal/models/group'

