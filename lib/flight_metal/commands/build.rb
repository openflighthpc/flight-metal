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
    class Build
      def initialize
        require 'flight_metal/server'
        require 'flight_metal/buildable_nodes'
        require 'flight_metal/log'
        require 'flight_metal/errors'
      end

      def run
        if buildable_nodes.empty?
          Log.warn_puts 'Nothing to build'
          return
        end

        Log.info_puts "Building: #{buildable_nodes.map(&:name).join(',')}"

        Server.new('0.0.0.0', Config.build_port, 256).loop do |message|
          if buildable_nodes.buildable?(message.node)
            Log.info_puts "#{message.node}: #{message.message}"
            if message.built?
              node = buildable_nodes.process_built(message.node)
              Log.info_puts "Built: #{node.name}"
            end
          else
            Log.warn_puts <<~WARN.squish
              Skipping message from '#{message.node}' as it's not currently
              being built
            WARN
          end
        end
      end

      def buildable_nodes
        @buildable_nodes ||= BuildableNodes.new('foo')
      end
    end
  end
end
