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

      delegate_missing_to :cache
    end

    def root_dir
      File.expand_path('../..', __dir__)
    end

    def path
      File.join(root_dir, 'etc/config.yaml')
    end

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

    def build_port
      __data__.fetch(:build_port) { 24680 }
    end
  end
end
