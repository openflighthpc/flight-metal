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

require 'flight_metal/server'
require 'flight_metal/models/node'

module FlightMetal
  module Commands
    class Build
      def initialize
        require 'flight_metal/models/node'
      end

      def run
        node_names = load_nodes.map(&:name)
        if node_names.empty?
          $stderr.puts 'Nothing to build'
          return
        end

        Server.new('127.0.0.1', 2000, 256).loop do |message|
          next true unless message.built?
          unless node_names.include?(message.node)
            $stderr.puts "Ignoring message from node: #{message.node}"
            next true
          end
          node = Models::Node.update(Config.cluster, message.node) do |node|
            node.built = true
          end
          puts "Built: #{node.name}"
          node_names.delete_if { |name| name == node.name }
          !node_names.empty?
        end
      end

      private

      def load_nodes
        Models::Node.glob_read(Config.cluster, '*')
                            .select do |node|
          if node.built?
            false
          elsif node.mac? && node.pxelinux_cfg?
            $stderr.puts <<~ERROR.squish
              Warning #{node.name}: Building off an existing pxelinux file -
              #{node.pxelinux_cfg_path}
            ERROR
            true
          elsif node.mac? && node.pxelinux_template?
            FileUtils.cp node.pxelinux_template_path,
                         node.pxelinux_cfg_path
            true
          elsif node.mac?
            $stderr.puts <<~ERROR.squish
              Skipping #{node.name}: Missing pxelinux source -
              #{node.pxelinux_template_path}
            ERROR
            false
          else
            $stderr.puts <<~ERROR.squish
              Skipping #{node.name}: Missing hardware address
            ERROR
            false
          end
        end
      end
    end
  end
end
