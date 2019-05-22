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
        require 'flight_metal/models/node'
        require 'flight_metal/server'
        require 'flight_metal/models/node'
        require 'flight_metal/log'
        require 'flight_metal/errors'
      end

      def run
        node_names = nodes.map(&:name)
        build_files # Puts the build files into place
        if node_names.empty?
          Log.warn_puts 'Nothing to build'
          return
        end

        Log.info_puts "Building: #{node_names.join(',')}"

        Server.new('127.0.0.1', Config.build_port, 256).loop do |message|
          unless node_names.include?(message.node)
            Log.warn "Ignoring message from node: #{message.node}"
            next true
          end
          Log.info_puts "#{message.node}: #{message.message}"if message.message
          if message.built?
            register_built(message)
            node_names.delete_if { |name| name == message.node }
            !node_names.empty?
          else
            # Process the next message
            true
          end
        end
      end

      private

      def nodes
        @nodes ||= begin
          Models::Node.glob_read(Config.cluster, '*')
                      .select(&:rebuild?)
                      .select do |node|
            if node.mac? && (node.pxelinux_template? || node.pxelinux_cfg?)
              Models::Node.update(Config.cluster, node.name) do |n|
                n.built = false
                n.rebuild = true
              end
              true
            elsif node.mac?
              Log.warn_puts <<~ERROR.squish
                Skipping #{node.name}: Missing pxelinux source -
                #{node.pxelinux_template_path}
              ERROR
              false
            else
              Log.warn_puts <<~ERROR.squish
                Skipping #{node.name}: Missing hardware address
              ERROR
              false
            end
          end
        end
      end

      def build_files
        @build_files ||= nodes.each_with_object({}) do |node, memo|
          if node.pxelinux_cfg?
            Log.warn_puts <<~ERROR.squish
              Warning #{node.name}: Building off an existing pxelinux file -
              #{node.pxelinux_cfg_path}
            ERROR
          else
            FileUtils.cp node.pxelinux_template_path,
                         node.pxelinux_cfg_path
          end
          memo[node.name] = [node.pxelinux_cfg_path]
          if node.kickstart_www?
            Log.warn_puts <<~WARN.squish
              Warning #{node.name}: Building off an existing kickstart file -
              #{node.kickstart_www_path}
            WARN
            memo[node.name] << node.kickstart_www_path
          elsif node.kickstart_template?
            FileUtils.mkdir_p File.dirname(node.kickstart_www_path)
            FileUtils.cp node.kickstart_template_path,
                         node.kickstart_www_path
            memo[node.name] << node.kickstart_www_path
          else
            Log.warn <<~WARN.squish
              Warning #{node.name}: No kickstart file detected
            WARN
          end
        end
      end

      def register_built(message)
        node = Models::Node.update(Config.cluster, message.node) do |n|
          build_files[n.name].each { |f| FileUtils.rm(f) }
          n.built = true
          n.rebuild = false
          n.bmc_user = message.bmc_username if message.bmc_username
          n.bmc_password = message.bmc_password if message.bmc_password
          n.bmc_ip = message.bmc_ip if message.bmc_ip
        end
        Log.info_puts <<~REPORT

          Build Report:  #{node.name}
          BMC Username:  #{node.bmc_user ? node.bmc_user : '-'}
          BMC Passsword: #{node.bmc_password ? 'SET' : '-'}
          BMC IP:        #{node.bmc_ip ? node.bmc_ip : '-'}
        REPORT
      end
    end
  end
end
