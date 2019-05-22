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
      flag :mac

      data_writer(:bmc_user)
      data_writer(:bmc_password)
      data_writer(:bmc_ip)

      data_reader(:bmc_user) { links.cluster.bmc_user }
      data_reader(:bmc_password) { links.cluster.bmc_password }

      alias_method :bmc_username, :bmc_user
      alias_method :bmc_username=, :bmc_user=

      data_reader :bmc_ip

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
        File.join(Config.kickstart_dir, "#{name}.ks")
      end

      def kickstart_www?
        File.exists? kickstart_www_path
      end

      def kickstart_template_path
        File.join(template_dir, cluster, "#{name}.ks")
      end

      def kickstart_template?
        File.exists? kickstart_template_path
      end

      def ipmi_opts
        "-H #{name}.bmc -U #{bmc_user} -P #{bmc_password}"
      end
    end
  end
end
