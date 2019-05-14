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

      def self.flag(name, fetch: nil)
        if fetch
          if fetch.respond_to?(:call)
            define_method(name) { fetch.call(__data__.fetch(name)) }
          else
            define_method(name) { __data__.fetch(name) }
          end
          define_method("#{name}?") { send(name) ? true : false }
        else
          define_method("#{name}?") { __data__.fetch(name) ? true : false }
        end

        define_method("#{name}=") do |value|
          __data__.set("__#{name}_time__",  value: Time.now.to_i)
          if value.nil?
            __data__.delete(name)
          else
            __data__.set(name, value: value)
          end
        end

        define_method(:"#{name}_time") do
          Time.at(__data__.fetch("__#{name}_time__") || 0)
        end
      end

      attr_reader :cluster, :name

      flag :built
      flag :rebuild
      flag :imported
      flag :mac, fetch: true

      def initialize(cluster, name)
        @cluster ||= cluster
        @name ||= name
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

      def pxelinux_cfg?
        File.exists?(pxelinux_cfg_path)
      end

      def pxelinux_cfg_path
        File.join(Config.tftpboot_dir,
                  'pxelinux.cfg',
                  '01-' + mac.downcase.gsub(':', '-')
                 )
      end

      def pxelinux_template?
        File.exists? pxelinux_template_path
      end

      def pxelinux_template_path
        File.join(template_dir, 'pxelinux.cfg', 'pxe_bios')
      end
    end
  end
end
