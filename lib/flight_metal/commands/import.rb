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
    class Import
      MANIFEST_PATH = 'kickstart/manifest.yaml'

      def initialize
        require 'pathname'

        require 'flight_metal/models/cluster'
        require 'flight_metal/models/node'
        require 'flight_metal/errors'
        require 'flight_metal/commands/node'
        require 'flight_metal/manifest'
      end

      def run(path, force: nil, init: nil)
        manifest = Manifests.load(path)
        # Update the cluster configuration
        if init || force
          identifier = init || current_cluster
          method = force ? :create_or_update : :create
          if force
            Log.warn_puts "Force updating cluster: #{identifier}"
          else
            Log.info_puts "Creating cluster: #{identifier}"
          end
          cluster = Models::Cluster.send(method, identifier) do |c|
            c.set_from_manifest(manifest.domain)
          end
          if init
            Log.info_puts "Switched to cluster: #{identifier}"
            Config.update { |c| c.cluster = cluster.identifier }
            Config.reset
          end
        end
        manifest.nodes.each do |node|
          if Models::Node.exists?(current_cluster, node.name) && force
            Log.warn_puts "Removing old configuration for: #{node.name}"
            Models::Node.delete!(current_cluster, node.name)
          end
          add_node(manifest.base, node)
        end
      end

      private

      def current_cluster(new_cluster = nil)
        @current_cluster = new_cluster if new_cluster
        @current_cluster ||= Config.cluster
      end

      def registry
        @registry ||= Registry.new
      end

      def add_node(base, manifest)
        inputs = manifest.symbolize_keys
                         .merge(cluster: current_cluster, base: base, registry: registry)
        Models::Node::Builder.new(**inputs).create
        Log.info_puts "Imported: #{manifest.name}"
      rescue => e
        Log.error_puts "Failed to import node_manifest: #{manifest.name}"
        Log.error_puts e
      end
    end
  end
end

