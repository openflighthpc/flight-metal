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

      def add_node(base, node)
        data = {
          "ip" => node.build_ip,
          "fqdn" => node.fqdn,
          "bmc_ip" => node.bmc_ip,
          "bmc_username" => node.bmc_username,
          "bmc_password" => node.bmc_password,
          "pxelinux_file" => node.pxelinux.expand_path(base).to_s,
          "kickstart_file" => node.kickstart.expand_path(base).to_s
        }
        Commands::Node.new.create(node.name, fields: YAML.dump(data))
        Log.info_puts "Imported: #{node.name}"
      rescue => e
        Log.error_puts "Failed to import node: #{node.name}"
        Log.error_puts e
      end
    end
  end
end

