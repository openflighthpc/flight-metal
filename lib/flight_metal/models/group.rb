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
require 'flight_metal/models/nodeattr'
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

      def join(*a)
        self.class.join(*__inputs__, *a)
      end

      TemplateMap.path_methods.each do |method, key|
        define_method(method) { join('libexec', TemplateMap.find_filename(key)) }
        define_path?(method)
      end
      define_type_path_shortcuts

      TemplateMap.path_methods(sub: 'template') do |method, key|
        define_method(method) { read_cluster.type_path(key) }
        define_path?(method)
      end
      define_type_path_shortcuts(sub: 'template')

      def load_cluster
       Models::Cluster.read(cluster, registry: __registry__)
      end

      def load_nodeattr
        Models::Nodeattr.read(cluster, registry: __registry__)
      end

      def load_nodes(primary: false)
        (primary ? primary_nodes : nodes).map do |node|
          Models::Node.read(cluster, name)
        end
      end

      def load_primary_nodes
        load_nodes(primary: true)
      end

      def nodes
        load_nodeattr.safe_nodes_in_group(name)
      end

      def primary_nodes
        load_nodeattr.safe_nodes_in_primary_group(name)
      end
    end
  end
end
