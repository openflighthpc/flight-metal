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

require 'flight_config'

module FlightMetal
  module Models
    class Node
      include FlightConfig::Updater
      include FlightConfig::Globber

      attr_reader :cluster, :name

      def initialize(cluster, name)
        @cluster ||= cluster
        @name ||= name
      end

      def mac
        __data__.fetch(:mac)
      end

      def mac=(address)
        if address.nil?
          __data__.delete(:mac)
        else
          __data__.set(:mac, value: address)
        end
      end

      def imported?
        __data__.fetch(:import_time) ? true : false
      end

      def update_import_time(time: Time.now.to_i)
        __data__.set(:import_time, value: time)
      end

      def import_time
        __data__.fetch(:import_time)
      end

      def path
        File.join(base_dir, 'etc/config.yaml')
      end

      def base_dir
        File.join(Config.content_dir, 'clusters', cluster, 'var/nodes', name)
      end

      def template_dir
        File.join(base_dir, 'var/templates')
      end

      def pxelinux_cfg_path
        File.join(Config.tftpboot_dir,
                  'pxelinux.cfg',
                  '01-' + mac.downcase.gsub(':', '-')
                 )
      end

      def pxelinux_template_path
        File.join(template_dir, 'pxelinux.cfg', 'pxe_bios')
      end
    end
  end
end
