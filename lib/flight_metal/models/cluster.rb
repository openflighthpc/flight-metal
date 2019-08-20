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
# For more information on flight-metal, please visit:
# https://github.com/alces-software/flight-metal
#===============================================================================

require 'flight_metal/model'

module FlightMetal
  module Models
    class Cluster < Model
      def self.join(identifier, *rest)
        Pathname.new(Config.content_dir).join('clusters', identifier, *rest)
      end

      def self.cache_join(identifier, *rest)
        Pathname.new(Config.content_dir).join('cache', 'clusters', identifier, *rest)
      end

      def self.path(identifier)
        join(identifier, 'etc/config.yaml')
      end
      define_input_methods_from_path_parameters

      flag :imported

      data_reader(:bmc_username) { 'default' }
      data_reader(:bmc_password) { 'default' }

      data_writer :bmc_username
      data_writer :bmc_password

      data_reader :gateway_ip
      data_writer :gateway_ip

      TemplateMap.path_methods.each do |method, type|
        define_method(method) do
          join('libexec', TemplateMap.find_filename(type))
        end

        define_path?(method)
      end
      define_type_path_shortcuts

      def read_nodes
        Models::Node.glob_read(identifier, '*', registry: __registry__)
      end

      def read_groups
        Models::Group.glob_read(identifier, '*', registry: __registry__)
      end
    end
  end
end
