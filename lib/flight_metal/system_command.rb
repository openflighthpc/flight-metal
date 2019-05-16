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
        return if code == 0
        raise SystemCommandError, <<~ERROR
          The following command exited with status #{code}:
          #{cmd}

          STDOUT:
          #{stdout}

          STDERR:
          #{stderr}
        ERROR
      end
    end

    attr_reader :nodes

    def initialize(*nodes)
      @nodes = nodes.flatten
    end

    def run
      return unless block_given?
      nodes.map { |n| CommandOutput.run(yield n) }
    end

    def ipmi(args)
      string_args = args.flatten.map(&:shellescape).join(' ')
      run { |n| "ipmitool -I lanplus #{n.ipmi_opts} #{string_args}" }
    end
  end
end

