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

require 'flight_metal/models/machine'
require 'flight_metal/models/cluster'
require 'flight_metal/models/group'
require 'flight_metal/macs'
require 'flight_metal/system_command'
require 'flight_metal/models/concerns/has_templates'

module FlightMetal
  module Models
    class Node < Model
      GROUP_STATIC_KEYS = [:groups, :other_groups, :primary_group]

      # Must be required after the class declaration
      require 'flight_metal/models/node/has_groups'

      include Concerns::HasTemplates
      include HasGroups

      def self.join(cluster, name, *a)
        Models::Cluster.join(cluster, 'var', 'nodes', name, *a)
      end

      def self.path(cluster, name)
        join(cluster, name, 'etc', 'config.yaml')
      end
      define_input_methods_from_path_parameters

      def self.delete!(*a)
        delete(*a) do |node|
          FileUtils.rm_rf node.join('machine')
          true
        end
      end

      flag :built
      flag :rebuild

      data_reader(:mac)
      data_writer(:mac) do |hwaddr|
        if hwaddr.nil? || hwaddr.empty?
          nil
        elsif self.mac == hwaddr
          mac
        elsif other = Macs.new(__registry__).find(hwaddr)
          raise InvalidModel, <<~ERROR.chomp
            Could not update mac address as it is currently being used in:
              - cluster: #{other.cluster}
              - name: #{other.name}
          ERROR
        else
          hwaddr.to_s
        end
      end

      data_reader(:other_params) { |p| (p || {}).symbolize_keys }
      data_writer(:other_params) do |raw|
        parsed = raw.to_h.select do |key, _|
          next true unless static_params.keys.include?(key)
          if GROUP_STATIC_KEYS.include?(key)
            msg = <<~WARN.squish
              Cowardly refusing to update the #{key} parameter for the node.
              See the following command for updating group membership:
            WARN
            Log.warn_puts <<~WARN.chomp
              #{msg}
              #{Config.app_name} group nodes --help
            WARN
          else
            Log.warn_puts <<~WARN.squish
              Cowardly refusing to set the #{key} parameter as it is static to
              the node
            WARN
          end
          false
        end
        parsed.symbolize_keys
      end

      def static_params
        {
          name: name,
          cluster: cluster,
          groups: groups.join(','),
          other_groups: other_groups.join(','),
          primary_group: primary_group,
          mac: mac
        }
      end

      def params
        other_params.merge(static_params)
      end

      def mac?
        !mac.nil?
      end

      def read_cluster
        Models::Cluster.read(cluster, registry: __registry__)
      end

      def read_machine
        Models::Machine.read(*__inputs__, registry: __registry__)
      end

      # TODO: Look how this integrates into FlightConfig
      # NOTE: This method does not share a registry and will cause all files to
      # reload. Consider refactoring?
      def update(&b)
        new_node = self.class.update(*__inputs__, &b)
        self.instance_variable_set(:@__data__, new_node.__data__)
      end

      private

      def deployable_type
        :machine
      end

      def raise_unless_valid_template_target(value)
        return if value == :machine
        raise InvalidInput, <<~ERROR.squish
          Nodes do not store templates for a #{value}
        ERROR
      end
    end
  end
end
