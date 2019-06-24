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

require 'flight_metal/config'
require 'flight_metal/registry'

module FlightMetal
  module Models
    class Cluster
      include FlightConfig::Updater
      include FlightConfig::Globber

      include FlightMetal::FlightConfigUtils

      attr_reader :identifier

      def initialize(identifier, **_h)
        @identifier = identifier
        super
      end

      def path
        File.join(Config.content_dir, 'clusters', identifier, 'etc/config.yaml')
      end

      flag :imported

      data_reader(:bmc_user) { 'default' }
      data_reader(:bmc_password) { 'default' }

      data_writer :bmc_user
      data_writer :bmc_password

      data_reader :gateway_ip
      data_writer :gateway_ip

      def set_from_manifest(man)
        self.bmc_user = man.bmc_username unless man.bmc_username.nil?
        self.bmc_password = man.bmc_password unless man.bmc_password.nil?
        self.gateway_ip = man.gateway_ip unless man.gateway_ip.nil?
      end

      def template_dir
        File.join(Config.content_dir, 'clusters', identifier, 'var/templates')
      end

      def post_hunt_script_path
        File.join(template_dir, 'post-hunt.sh')
      end

      def post_hunt_script?
        File.exists? post_hunt_script_path
      end
    end
  end
end
