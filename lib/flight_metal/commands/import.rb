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

        require 'flight_metal/models/node'
        require 'flight_metal/errors'
        require 'flight_metal/commands/node'
        require 'flight_metal/manifest'
      end

      def run(path)
        manifest = Manifests.load(path)
        manifest.nodes.each { |node| add_node(manifest.base, node) }
      end

      private

      def add_node(base, node_manifest)
        Models::Node.from_manifest(node_manifest).create(Config.cluster)
        Log.info_puts "Imported: #{node_manifest.name}"
      rescue => e
        Log.error_puts "Failed to import node_manifest: #{node_manifest.name}"
        Log.error_puts e
      end
    end
  end
end

