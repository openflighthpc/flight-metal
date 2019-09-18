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
require 'flight_metal/models/cluster'
require 'flight_metal/models/node'
require 'flight_metal/indices/group_and_node'

module FlightMetal
  module Models
    class Group < Model
      allow_missing_read

      def self.join(cluster, name, *a)
        Models::Cluster.join(cluster, 'var', 'groups', name, *a)
      end

      def self.cache_join(cluster, name, *a)
        Models::Cluster.cache_join(cluster, 'groups', name, *a)
      end

      def self.path(cluster, name)
        join(cluster, name, 'etc', 'config.yaml')
      end
      define_input_methods_from_path_parameters

      def read_cluster
       Models::Cluster.read(cluster, registry: __registry__)
      end

      def read_nodes
        Indices::GroupAndNode.glob_read(cluster, name, '*', '*')
                             .map(&:read_node)
                             .uniq
      end

      def read_other_nodes
        Indices::GroupAndNode.glob_read(cluster, name, '*', :other).map(&:read_node)
      end

      def read_primary_nodes
        Indices::GroupAndNode.glob_read(cluster, name, '*', :primary).map(&:read_node)
      end

      def nodes
        read_nodes.map(&:name)
      end

      def primary_nodes
        read_primary_nodes.map(&:name)
      end
    end
  end
end
