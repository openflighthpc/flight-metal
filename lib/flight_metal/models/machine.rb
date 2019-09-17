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

require 'flight_metal/template_map'
require 'flight_metal/models/cluster'

module FlightMetal
  module Models
    class Machine < Model
      allow_missing_read

      def self.path(cluster, name)
        join(cluster, name, 'etc', 'machine.yaml')
      end

      def self.join(cluster, name)
        Models::Cluster.join(cluster, 'var', 'nodes', name, *a)
      end

      def read_node
        Models::Node.read(*__inputs__, registry: __registry__)
      end

      def file_path(type)
        TemplateMap.raise_unless_valid_type(type)
        join('rendered', TemplateMap.find_filename(type))
      end

      def file?(type)
        File.exists? file_path(type)
      end

      def source_model(type)
        if (node = read_node).template?(type)
          node
        else
          nil
        end
      end

      def source?(type)
        source_model(type) ? true : false
      end

      def source_path(type)
        if model = source_model(type)
          model.template_path(type)
        else
          raise InvalidModel, <<~ERROR
            Could not locate the source template for '#{name}' #{type} file
          ERROR
        end
      end
    end
  end
end

require 'flight_metal/models/node'
