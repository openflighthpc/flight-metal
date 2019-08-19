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
    class Update < ScopedCommand
      command_require 'flight_metal/models/node'

      def group(*params)
        Models::Group.update(Config.cluster, model_name_or_error) do |group|
          group.merge_params!(parse_param_strings(*params))
        end
      end

      def node(*params, rebuild: nil)
        rebuild = if rebuild.nil?
                    nil
                  elsif [false, 'false'].include?(rebuild)
                    false # Treat 'false' as false
                  else
                    true
                  end
        hash = parse_param_strings(*params)
        Models::Node.update(Config.cluster, model_name_or_error) do |node|
          node.merge_params!(hash)
          node.rebuild = rebuild unless rebuild.nil?
        end
      end

      private

      def parse_param_strings(*params)
        update_hash = params.select { |p| /\A\w+=.*/.match?(p) }
                            .map { |p| p.split('=', 2) }
                            .to_h
                            .symbolize_keys
        delete_keys = params.select { |p| /\A\w+!/.match?(p) }
                            .map { |p| p[0..-2].to_sym }
        update_hash.merge(delete_keys.map { |k| [k, nil] }.to_h)
      end
    end
  end
end
