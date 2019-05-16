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
    class Ipmi
      POWER_COMMANDS = {
        'on'        => ['chassis', 'power', 'on'],
        'off'       => ['chassis', 'power', 'off'],
        'locate'    => ['chassis', 'identify', 'force'],
        'locateoff' => ['chassis', 'identify', '0'],
        'status'    => ['chassis', 'power', 'status'],
        'cycle'     => ['chassis', 'power', 'cycle'],
        'reset'     => ['chassis', 'power', 'reset'],
        'sensor'    => ['sensor']
      }

      def initialize
        require 'flight_metal/models/node'
        require 'flight_metal/system_command'
        require 'flight_metal/errors'
      end

      def power(name, cmd)
        ipmi_cmd = POWER_COMMANDS[cmd]
        raise InvalidInput <<~ERROR.chomp unless ipmi_cmd
          '#{cmd}' is not a valid power command. Please select one of the following:
          #{POWER_COMMANDS.keys.join(',')}
        ERROR
        run(name, *ipmi_cmd)
      end

      def run(name, *args)
        if name == 'help'
          puts ipmi_help
        elsif args.empty?
          raise SystemCommandError, <<~ERROR
            No command provided to ipmitool. Please select one from the list below
            #{ipmi_cmds}
          ERROR
        else
          node = Models::Node.read(Config.cluster, name)
          run_cmd(node, args)
        end
      end

      private

      def ipmi_cmds
        lines = ipmi_help.split("\n")
        loop until /\ACommands:/.match?(lines.shift)
        lines.join("\n")
      end

      def ipmi_help
        _, help_text = Open3.capture3('ipmitool -h')
        help_text
      end

      def run_cmd(node, args)
        output = SystemCommand.new(node).ipmi(args).first
        output.raise_unless_exit_0
        puts output.stdout
      end
    end
  end
end
