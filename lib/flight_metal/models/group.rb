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

require 'flight_config'
require 'flight_metal/models/cluster'
require 'flight_metal/template_map'

module FlightMetal
  module Models
    class Group
      include FlightConfig::Reader
      include FlightConfig::Updater
      include FlightConfig::Accessor

      include TemplateMap::PathAccessors

      allow_missing_read

      def self.join(cluster, name, *a)
        Models::Cluster.join(cluster, 'var', 'groups', name, *a)
      end

      def self.path(cluster, name)
        join(cluster, name, 'etc', 'config.yaml')
      end
      define_input_methods_from_path_parameters

      def self.node_symlink_path(cluster, group, node)
        join(cluster, group, 'nodes', "#{node}.link")
      end

      def join(*a)
        self.class.join(*__inputs__, *a)
      end

      def node_symlink_path(node)
        self.class.node_symlink_path(*__inputs__, node)
      end

      TemplateMap.path_methods.each do |method, key|
        define_method(method) { join('libexec', TemplateMap.find_filename(key)) }
        define_path?(method)
      end
      define_type_path_shortcuts

      TemplateMap.path_methods(sub: 'template').each do |method, key|
        define_method(method) { read_cluster.type_path(key) }
        define_path?(method)
      end
      define_type_path_shortcuts(sub: 'template')

      def read_cluster
       Models::Cluster.read(cluster, registry: __registry__)
      end

      def read_nodes(primary: false)
        nodes = Dir.glob(node_symlink_path('*')).map do |path|
          FlightConfig::Globber::Matcher.new(Models::Node, 2, __registry__)
                                        .read(Pathname.new(path).readlink.to_s)
        end
        bad_nodes = nodes.reject { |n| n.groups.include?(name) }
        bad_nodes.each { |n| FileUtils.rm node_symlink_path(n.name) }
        good_nodes = nodes - bad_nodes
        primary ? good_nodes.select { |n| n.primary_group == name } : good_nodes
      end

      def read_primary_nodes
        read_nodes(primary: true)
      end
    end
  end
end
