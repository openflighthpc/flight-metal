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
  module Commands
    class Cluster
      TEMPLATE = <<~ERB
        # NOTE: Editing this file will set the state information of the cluster
        # The following conventions are used when editing:
        #  > Fields will skip updating if:
        #    1. The field is deleted
        #    2. The value is set to null
        #  > Fields can be unset by passing an empty string (*when supported)
        #  > Use the --fields flag to edit in a non-interactive shell
        #  > Only the listed fields can be edited

        # NOTE: When using the --fields flag, the attributes will not be
        # pre-populated. All attributes need to manually set.

        # Set the default bmc username/password and gateway ip. For the cluster
        # All the nodes in the cluster will default to this value unless overridden
        bmc_username: <%= nil_to_null bmc_user %>
        bmc_password: <%= nil_to_null bmc_password %>
        gateway_ip: <%= nil_to_null gateway_ip %>
      ERB

      def initialize
        require 'flight_metal/models/cluster'
        require 'flight_metal/templator'
        require 'flight_manifest'
      end

      def init(identifier, fields: nil)
        cluster = Models::Cluster.create(identifier) do |c|
          update_cluster_fields(c, fields)
        end

        Config.create_or_update { |c| c.cluster = cluster.identifier }
        Config.reset
        puts "Created cluster: #{cluster.identifier}"
      end

      def list
        Config.cluster # Ensures that at least the default cluster exists
        id_strs = Models::Cluster.glob_read('*')
                            .map(&:identifier)
                            .map do |id|
          "#{id == Config.cluster ? '*' : ' '} #{id}"
        end
        puts id_strs.join("\n")
      end

      def switch(identifier)
        cluster = Models::Cluster.read(identifier)
        Config.create_or_update { |c| c.cluster = cluster.identifier }
        puts "Switched cluster: #{cluster.identifier}"
      end

      def edit(fields: nil)
        Models::Cluster.create_or_update(Config.cluster) do |cluster|
          update_cluster_fields(cluster, fields)
        end
      end

      private

      def update_cluster_fields(cluster, fields)
        yaml = if fields
                 YAML.safe_load(fields, symbolize_names: true)
               else
                 Templator.new(cluster).edit_yaml(TEMPLATE)
               end
        manifest = FlightManifest::Domain.new(**yaml)
        cluster.set_from_manifest(manifest)
      end
    end
  end
end

