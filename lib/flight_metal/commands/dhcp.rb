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
    class DHCP < Command
      command_require 'flight_metal/models/node'
      command_require 'flight_metal/templator'
      command_require 'flight_metal/log'
      command_require 'flight_metal/system_command'

      DHCP_TEMPLATE = <<~ERB
      host <%= name %> {
        hardware ethernet <%= mac %>;
        option host-name "<%= fqdn %>";
      <%# option routers GATEWAY_IP;  -- TODO: Workout how to do gateways -%>
        fixed-address <%= ip %>;
      }
      ERB

      def update
        conf = Models::Node.glob_read(Config.cluster, '*')
                           .select(&:mac)
                           .map { |n| Templator.new(n).render(DHCP_TEMPLATE) }
                           .join("\n")
        File.write Config.dhcpd_path, <<~DHCP
          # This file is managed by '#{Config.app_name}' and maybe replaced
          # without notice. All external changes to the file will be lost
          #
          # Place all other dhcp configuration in a separate file

          #{conf}
        DHCP
        Log.info_puts <<~MSG
          Rendered the dhcpd configuration file: #{Config.dhcpd_path}
          Please ensure it's included in the main dhcpd configuration
          Restarting DHCP...
        MSG
        SystemCommand::CommandOutput.run(Config.restart_dhcpd_command)
                                    .raise_unless_exit_0
        Log.info_puts 'Done'
      end
    end
  end
end

