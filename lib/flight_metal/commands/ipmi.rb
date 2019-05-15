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
      def initialize
        require 'flight_metal/models/node'
        require 'open3'
        require 'flight_metal/errors'
      end

      def run(name, *args)
        node = Models::Node.read(Config.cluster, name)
        ipmi_cmd = <<~CMD.squish
          ipmitool -I lanplus #{node.ipmi_opts}
                      #{args.map(&:shellescape).join(' ')}
        CMD
        run_cmd(ipmi_cmd)
      end

      def run_cmd(cmd)
        Log.info("System Command: #{cmd}")
        stdout, stderr, status = Open3.capture3(cmd)
        if status.exitstatus == 0
          puts stdout
        else
          raise SystemCommandError, <<~ERROR
            The following command has exited with status #{status.exitstatus}:
            #{cmd}

            STDOUT:
            #{stdout}

            STDERR:
            #{stderr}
          ERROR
        end
      end
    end
  end
end
