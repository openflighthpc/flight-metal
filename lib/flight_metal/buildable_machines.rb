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

require 'flight_metal/models/machine'

module FlightMetal
  class BuildableMachines < Array
    def initialize(machines)
      buildable_machines = machines.reject do |machine|
        next if machine.buildable?
        if machine.rebuild?
          Log.warn_puts <<~WARN.chomp
            Skipping #{machine.name}: It can not be built at this time
          WARN
        end
        true
      end
      super(buildable_machines)
    end

    def buildable?(name)
      find_name(name) ? true : false
    end

    def install_build_files
      each do |machine|
        [:kickstart, :pxelinux, :dhcp].each do |type|
          next unless machine.type_status(type) == :pending
          sys = machine.type_system_path(type)
          FileUtils.mkdir_p File.dirname(sys)
          FileUtils.ln_s machine.type_path(type), sys
        end
      end
    end

    def process_built(name)
      machine = find_name(name)
      Models::Node.update(*machine.__inputs__) do |n|
        FileUtils.rm_f machine.pxelinux_system_path
        FileUtils.rm_f machine.kickstart_system_path
        n.rebuild = false
        n.built = true
      end
      delete(machine)
    end

    def find_name(name)
      find { |n| n.name == name }
    end
  end
end
