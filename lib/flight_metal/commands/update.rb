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

module FlightMetal
  module Commands
    class Update < ScopedCommand
      Params = Struct.new(:params) do
        def merge_hash
          params.select { |p| /\A\w+=.*/.match?(p) }
                .map { |p| p.split('=', 2) }
                .to_h
                .symbolize_keys
        end

        def delete_keys
          params.select { |p| /\A\w+!/.match?(p) }
                .map { |p| p[0..-2].to_sym }
        end

        def update!(hash)
          hash.merge!(merge_hash)
          delete_keys.each { |k| hash.delete(k) }
          hash
        end
      end

      command_require 'flight_metal/models/node', 'tty-editor'

      def node(*param_strs)
        Models::Node.update(*read_node.__inputs__) do |node|
          builder = Params.new(param_strs)
          node.other_params = builder.update!(node.other_params.dup)
        end
      end
    end
  end
end
