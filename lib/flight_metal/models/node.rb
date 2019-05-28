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
require 'flight_metal/registry'
require 'flight_metal/models/cluster'
require 'flight_metal/errors'
require 'flight_metal/macs'
require 'flight_metal/system_command'

module FlightMetal
  module Models
    class Node
      NodeLinks = Struct.new(:node) do
        def cluster
          read(Models::Cluster, node.cluster)
        end

        private

        def read(klass, *a)
          node.__registry__.read(klass, *a)
        end
      end

      include FlightConfig::Updater
      include FlightConfig::Globber

      include FlightMetal::FlightConfigUtils

      attr_reader :cluster, :name

      flag :built
      flag :rebuild
      flag :imported
      flag :mac, set: ->(original_mac) do
        original_mac.tap do |mac|
          if mac.nil? || mac.empty?
            next
          elsif node = Macs.new(__registry__).find(mac)
            raise InvalidModel, <<~ERROR.squish
              Failed to update mac address '#{mac}' as it is already taken by:
              node '#{node.name}' in cluster '#{node.cluster}'
            ERROR
          end
        end
      end

      data_writer(:bmc_user)
      data_writer(:bmc_password)
      data_writer(:bmc_ip)

      data_reader(:bmc_user) { links.cluster.bmc_user }
      data_reader(:bmc_password) { links.cluster.bmc_password }

      alias_method :bmc_username, :bmc_user
      alias_method :bmc_username=, :bmc_user=

      data_reader :bmc_ip

      data_reader(:ip) do
        gethostip_set_if_empty
        __data__.fetch(:ip)
      end

      data_reader(:fqdn) do
        gethostip_set_if_empty
        __data__.fetch(:fqdn)
      end

      def initialize(cluster, name)
        @cluster ||= cluster
        @name ||= name
      end

      def links
        @models ||= NodeLinks.new(self)
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

      def kickstart_www_path
        File.join(Config.kickstart_dir, cluster, "#{name}.ks")
      end

      def kickstart_www?
        File.exists? kickstart_www_path
      end

      def kickstart_template_path
        File.join(template_dir, "#{name}.ks")
      end

      def kickstart_template?
        File.exists? kickstart_template_path
      end

      def ipmi_opts
        "-H #{name}.bmc -U #{bmc_user} -P #{bmc_password}"
      end

      private

      def gethostip_set_if_empty
        SystemCommand.new(self)
                     .run(cmd: ->(n) { "gethostip -nd #{n.name}" })
                     .first
                     .tap(&:raise_unless_exit_0)
                     .stdout
                     .split
                     .tap do |fqdn, ip|
          __data__.set_if_empty(:fqdn, value: fqdn)
          __data__.set_if_empty(:ip, value: ip)
        end
      end
    end
  end
end
