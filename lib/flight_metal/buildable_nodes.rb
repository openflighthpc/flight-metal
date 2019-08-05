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

require 'flight_metal/models/node'

module FlightMetal
  class BuildableNodes < Array
    Loader = Struct.new(:cluster, :registry) do
      def nodes
        read_hash_nodes.reject do |hash|
          [:pxelinux, :kicksart, :dhcp].each do |type|
            node = hash[:node]
            next true unless node.rebuild?
            next true unless is_buildable?(type, **hash)
          end
        end
      end

      private

      def read_nodes
        Models::Node.glob_read(cluster, '*', registry: registry)
      end

      def read_hash_nodes
        read_nodes.map do |node|
          {
            node: node,
            statuses: {
              pxelinux: node.pxelinux_status,
              kickstart: node.kickstart_status,
              dhcp: node.dhcp_status
            }
          }
        end
      end

      def is_buildable?(type, node:, statuses:)
        case statuses[type]
        when :installed
          Log.warn_puts <<~MSG.squish
            #{node.name}: Using existing #{type} file:
            #{node.public_send("#{type}_system_path")}
          MSG
          true
        when :pending
          true
        else
          false
        end
      end
    end

    def initialize(cluster)
      super(Loader.new(cluster).nodes)
    end

    def buildable?(name)
      find_name(name) ? true : false
    end

    def process_built(name)
      node = find_name(name)
      Models::Node.update(*node.__inputs__) do |n|
        FileUtils.rn n.pxelinux_system_path
        FileUtils.rn n.kickstart_system_path
        n.rebuild = false
        n.built = true
      end
      delete(node)
    end

    def find_name(name)
      find { |n| n.name == name }
    end
  end
end
