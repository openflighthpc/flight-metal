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

module FlightMetal
  module Commands
    class Build
      def initialize
        require 'flight_metal/models/node'
      end

      def run
        Models::Node.glob_read(Config.cluster, '*')
                    .each do |node|
          if node.mac.nil?
            $stderr.puts "Skipping #{node.name}: Missing hardware address"
          elsif File.exists?(node.pxelinux_cfg_path)
            $stderr.puts <<~ERROR.squish
              Skipping #{node.name}: Pxelinux file already exists:
              #{node.pxelinux_cfg_path}
            ERROR
          elsif node.pxelinux_template_path
            FileUtils.cp node.pxelinux_template_path, node.pxelinux_cfg_path
            $stderr.puts <<~MSG.squish
              Copied #{node.name} pxelinux file: #{node.pxelinux_cfg_path}
            MSG
          end
        end

        Server.new('127.0.0.1', 2000, 256).loop do |message|
          puts message
        end
      end
    end
  end
end
