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
      BUILD_TYPES = [:kickstart, :dhcp, :pxelinux].freeze

      allow_missing_read

      def self.path(cluster, name)
        join(cluster, name, 'etc', 'config.yaml')
      end
      define_input_methods_from_path_parameters

      def self.join(cluster, name, *a)
        Models::Cluster.join(cluster, 'var', 'nodes', name, 'machine', *a)
      end

      def buildable?
        missing_build_types.empty?
      end

      def missing_build_types
        BUILD_TYPES.reject { |t| file?(t) }
      end

      def read_cluster
        Models::Cluster.read(cluster, registry: __registry__)
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

      def read_file(type)
        File.read file_path(type)
      end

      def system_file_path(type)
        if BUILD_TYPES.include?(type)
          case type
          when :pxelinux
            File.join(
              Config.tftpboot_dir,
              'pxelinux.cfg',
              '01-' + read_node.mac.downcase.gsub(':', '-')
            )
          when :kickstart
            File.join(Config.kickstart_dir, name + '.ks')
          when :dhcp
            File.join(Config.dhcpd_dir, name + '.conf')
          else
            raise InternalError
          end
        else
          raise InvalidInput, <<~ERROR
            '#{type}' is not a build file and does not have a system location
          ERROR
        end
      end

      def system_file?(type)
        path = Pathname.new(system_file_path(type))
        path.symlink? || path.exists?
      end

      def system_file_correctly_linked?(type)
        path = Pathname.new(system_file_path(type))
        path.symlink? && path.readlink == file_path(type)
      end

      def system_file_installed?(type)
        system_file_correctly_linked?(type) && file?(type)
      end

      def link_system_file(type)
        sys = system_file_path(type)
        FileUtils.mkdir_p File.dirname(sys)
        FileUtils.ln_s file_path(type), sys
      end

      def source_model(type)
        if (node = read_node).template?(type, to: :machine)
          node
        elsif (cluster_model = read_cluster).template?(type, to: :machine)
          cluster_model
        else
          nil
        end
      end

      def source?(type)
        source_model(type) ? true : false
      end

      def source_path(type)
        if model = source_model(type)
          model.template_path(type, to: :machine)
        else
          raise InvalidModel, <<~ERROR
            Could not locate the source template for '#{name}' #{type} file
          ERROR
        end
      end

      def renderer(type)
        if source = source_model(type)
          read_node.renderer(type, source: source)
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
