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
require 'active_support/core_ext/module/delegation'
require 'flight_metal/models/cluster'

module FlightMetal
  class Config
    include FlightConfig::Updater

    allow_missing_read

    class << self
      def cache
        @cache ||= self.read
      end

      def root_dir
        File.expand_path('../..', __dir__)
      end

      # TODO: Investigate why an array is being passed, it is likely due to the
      # delegation within FlightConfig
      def path(*_a)
        File.join(root_dir, 'etc/config.yaml')
      end

      def reset
        @cache = nil
      end

      delegate_missing_to :cache
    end

    delegate :root_dir, :path, to: Config

    def app_name
      'metal'
    end

    def log_path
      __data__.fetch(:log_path) do
        File.join(root_dir, 'var/log/metal.log')
      end
    end

    def content_dir
      __data__.fetch(:content_dir) do
        File.expand_path('var', root_dir)
      end
    end

    def cluster
      __data__.fetch(:cluster) do
        Models::Cluster.create_or_update('default').identifier
      end
    end

    def cluster=(name)
      __data__.set(:cluster, value: name)
    end

    def interface
      __data__.fetch(:interface) { 'eth0' }
    end

    def node_prefix
      __data__.fetch(:node_prefix) { 'node' }
    end

    def node_index_length
      __data__.fetch(:node_index_length) { 2 }
    end

    def tftpboot_dir
      __data__.fetch(:tftpboot_dir) { '/var/lib/tftpboot' }
    end

    def kickstart_dir
      __data__.fetch(:kickstart_dir) { '/var/www/kickstart' }
    end

    def build_port
      __data__.fetch(:build_port) { 24680 }
    end

    def dhcpd_dir
      __data__.fetch(:dhcpd_dir) { '/etc/dhcp/dhcpd.flight' }
    end

    def restart_dhcpd_command
      __data__.fetch(:restart_dhcpd_command) { 'systemctl restart dhcpd' }
    end

    # Cache the list of ipmi commands so it can be included as part of the CLI
    # help. This prevents the need to run a `ipmi` system command every time the CLI
    # is executed
    def ipmi_commands_help
      __data__.fetch(:ipmi_commands_help) do
        config = self.class.create_or_update do |conf|
          require 'open3'
          _, help_text, status = Open3.capture3('ipmitool -h')
          raise InternalError, <<~ERROR.squish.chomp unless status.success?
            Failed to parse `ipmitool` command output, please ensure it is
            installed correctly.
          ERROR
          lines = help_text.split("\n")
          loop until /\ACommands:/.match?(lines.shift)
          lines.join("\n")
          conf.__data__.set(:ipmi_commands_help, value: lines.join("\n"))
        end
        config.ipmi_commands_help
      end
    end

    def debug
      __data__.fetch(:debug) { false }
    end
  end
end
