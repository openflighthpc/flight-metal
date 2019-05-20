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

require 'flight_metal/commands/concerns/nodeattr_parser'

module FlightMetal
  module Commands
    class Ipmi < Command
      command_require 'flight_metal/system_command',
                      'flight_metal/errors'

      include Concerns::NodeattrParser

      POWER_COMMANDS = {
        'on' => {
          cmd: ['chassis', 'power', 'on'],
          help: 'Turns the node on'
        },
        'off' => {
          cmd: ['chassis', 'power', 'off'],
          help: 'Turns the node off'
        },
        'locate' => {
          cmd: ['chassis', 'identify', 'force'],
          help: 'Turns the node locater light on'
        },
        'locateoff' => {
          cmd: ['chassis', 'identify', '0'],
          help: 'Turns the node locater light off'
        },
        'status' => {
          cmd: ['chassis', 'power', 'status'],
          help: 'Display the power status'
        },
        'cycle' => {
          cmd: ['chassis', 'power', 'cycle'],
          help: 'Power cycle the node'
        },
        'reset' => {
          cmd: ['chassis', 'power', 'reset'],
          help: 'Warm reset the node'
        }
      }

      def power(names_str, cmd)
        power_cmd = POWER_COMMANDS[cmd]
        raise InvalidInput, <<~ERROR.chomp unless power_cmd
          '#{cmd}' is not a valid power command. Please select one of the following:
          #{POWER_COMMANDS.keys.join(',')}
        ERROR
        run(names_str, *power_cmd[:cmd])
      end

      def run(names_str, *args)
        if names_str == 'help'
          puts ipmi_help
        elsif args.empty?
          raise SystemCommandError, <<~ERROR
            No command provided to ipmitool. Please select one from the list below
            #{ipmi_cmds}
          ERROR
        else
          nodes = nodeattr_parser(names_str)
          raise InvalidInput, <<~ERROR.squish unless nodes.all_exist?
            The following nodes do not exist:
            #{nodes.missing.map(&:name).join(',')}
          ERROR
          nodes.each do |node|
            run_cmd(node, args)
          end
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
