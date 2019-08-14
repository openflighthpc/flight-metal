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
    class Node < Command

      command_require 'flight_metal/models/node',
                      'flight_metal/system_command'

      def update(name, *params, rebuild: nil)
        rebuild = if rebuild.nil?
                    nil
                  elsif [false, 'false'].include?(rebuild)
                    false # Treat 'false' as false
                  else
                    true
                  end
        update_hash = params.select { |p| /\A\w+=.*/.match?(p) }
                            .map { |p| p.split('=', 2) }
                            .to_h
                            .symbolize_keys
        delete_keys = params.select { |p| /\A\w+!/.match?(p) }
                            .map { |p| p[0..-2].to_sym }
        Models::Node.update(Config.cluster, name) do |node|
          new = node.params.merge(update_hash)
          delete_keys.each { |k| new.delete(k) }
          node.params = new
          node.rebuild = rebuild unless rebuild.nil?
        end
      end

      def delete(name)
        Models::Node.delete!(Config.cluster, name)
      end
    end
  end
end
