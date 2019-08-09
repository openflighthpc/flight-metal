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
    class Ipmi < Command
      command_require 'flight_metal/system_command',
                      'flight_metal/template_map',
                      'flight_metal/models/node',
                      'flight_metal/errors',
                      'shellwords'

      [:power_on, :power_off, :power_status, :ipmi].each do |type|
        define_method(type) do |name, *shell_args, nodes_in: nil, primary_nodes_in: nil|
          nodes = if nodes_in
            Models::Group.read(Config.cluster, name).read_nodes
          elsif primary_nodes_in
            Models::Group.read(Config.cluster, name).read_primary_nodes
          else
            [Models::Node.read(Config.cluster, name)]
          end
          run_cmd(nodes, type, *shell_args)
        end
      end

      private

      def run_cmd(nodes, type, *shell_args)
        nodes.each do |node|
          if node.type_path?(type)
            args_str = shell_args.map { |s| Shellwords.shellescape(s) }.join(' ')
            cmd = "bash #{node.type_path(type)} #{args_str}"
            out = SystemCommand::CommandOutput.run(cmd)
            if out.exit_0?
              puts out.stdout
            else
              puts out.verbose
            end
          else
            Log.warn_puts <<~WARN.squish
              Skipping #{node.name}: The #{TemplateMap.flag(type)} file
              can not be found: #{node.type_path(type)}
            WARN
          end
        end
      end
    end
  end
end
