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
    class CreateNode < Command
      command_require 'flight_metal/models/node'

      def run(node, pxe_file, kickstart,
              mac: nil,
              bmc_ip: nil,
              bmc_username: nil,
              bmc_password: nil)
        Models::Node.create(Config.cluster, node) do |n|
          FileUtils.mkdir_p File.dirname(n.pxelinux_template_path)
          FileUtils.cp pxe_file, n.pxelinux_template_path
          FileUtils.cp kickstart, n.kickstart_template_path
          n.mac = mac
          n.bmc_username = bmc_username
          n.bmc_password = bmc_password
          n.bmc_ip = bmc_ip
        end
      end
    end
  end
end
