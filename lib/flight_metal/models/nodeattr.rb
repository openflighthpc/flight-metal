#==============================================================================
# Copyright (C) 2019-present Alces Flight Ltd.
#
# This file is part of NodeattrUtils.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License 2.0 which is available at
# <https://www.eclipse.org/legal/epl-2.0>, or alternative license
# terms made available by Alces Flight Ltd - please direct inquiries
# about licensing to licensing@alces-flight.com.
#
# NodeattrUtils is distributed in the hope that it will be useful, but
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR
# IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS
# OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A
# PARTICULAR PURPOSE. See the Eclipse Public License 2.0 for more
# details.
#
# You should have received a copy of the Eclipse Public License 2.0
# along with NodeattrUtils. If not, see:
#
#  https://opensource.org/licenses/EPL-2.0
#
# For more information on NodeattrUtils, please visit:
# https://github.com/openflighthpc/nodeattr_utils
#==============================================================================

require 'nodeattr_utils'
require 'nodeattr_utils/config'
require 'flight_metal/models/cluster'

module FlightMetal
  module Models
    class Nodeattr < NodeattrUtils::Config
      allow_missing_read

      def self.create_or_update!(*a, &b)
        update(*a) do |attr|
          attr.purge!
          b.call(attr) if b
          attr.purge!
        end
      end

      def self.path(cluster)
        Models::Cluster.join(cluster, 'etc/nodeattr.yaml')
      end

      # Remove all node entries that are missing, this is required in case a file
      # gets deleted unceremoniously. Groups do not get the same treatment as they
      # can read missing configs
      def purge!
        nodes_list.each do |node|
          next if Models::Node.exists?(cluster, node)
          Log.error_puts "Removing unknown node from nodeattr list: #{node}"
          remove_nodes(node)
        end
      end

      def safe_nodes_in_group(group, primary: false)
        nodes = (primary ? nodes_in_primary_group(group) : nodes_in_group(group))
        # Add all missing nodes to the orphan group
        if group  == 'orphan'
          binding.pry
          all_nodes = Models::Node.glob_read(cluster, '*', registry: __registry__)
                                  .map(&:name)
          nodes = [*nodes, *(all_nodes - nodes_list)]
        end
        nodes.reject do |node|
          unless Models::Node.exists?(cluster, node)
            Log.warn "Skipping unknown node in nodeattr list: #{node}"
            true
          end
        end
      end

      def safe_nodes_in_primary_group(group)
        safe_nodes_in_group(group, primary: true)
      end
    end
  end
end
