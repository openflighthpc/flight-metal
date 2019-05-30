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

require 'flight_metal/errors'
require 'open3'

module FlightMetal
  class SystemCommand
    CommandOutput = Struct.new(:cmd, :stdout, :stderr, :status) do
      def self.run(cmd)
        Log.info("System Command: #{cmd}")
        new(cmd, *Open3.capture3(cmd))
      end

      delegate :success?, :pid, to: :status

      def code
        status.exitstatus
      end

      def raise_unless_exit_0
        return if exit_0?
        raise SystemCommandError, verbose
      end

      def exit_0?
        code == 0
      end

      def verbose
        <<~VERBOSE
          COMMAND: #{cmd}
          CODE: #{code}
          STDOUT:
          #{stdout}
          STDERR:
          #{stderr}
        VERBOSE
      end
    end

    attr_reader :nodes

    def initialize(*nodes)
      @nodes = nodes.flatten
    end

    def run(cmd:, output: nil)
      nodes.map do |node|
        str_cmd = (cmd.respond_to?(:call) ? cmd.call(node) : cmd)
        CommandOutput.run(str_cmd).tap do |out|
          output.call(out) if output.respond_to?(:call)
        end
      end
    end

    def ipmi(*args, &b)
      string_args = args.flatten.map(&:shellescape).join(' ')
      run cmd: proc { |n| "ipmitool -I lanplus #{n.ipmi_opts} #{string_args}" },
          output: b
    end

    def fqdn_and_ip
      run cmd: proc { |n| "gethostip -nd #{n.name.shellescape}" }
    end
  end
end

