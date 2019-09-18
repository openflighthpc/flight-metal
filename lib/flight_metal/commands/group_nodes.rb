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
    class GroupNodes < ScopedCommand
      command_require 'flight_metal/models/node'

      def add(*nodes)
        group_name = model_name_or_error
        nodes = nodes.reject do |node|
          next if Models::Node.exists?(Config.cluster, node)
          Log.warn_puts <<~WARN.squish
            Skipping node '#{node}' as it does not exist
          WARN
          true
        end
        nodes.each do |node_name|
          Models::Node.update(Config.cluster, node_name) do |node|
            if is_primary? && node.primary_group == group_name
              # noop
            elsif is_primary?
              node.primary_group = read_group.tap(&:__data__).name
            elsif node.other_groups.include?(group_name)
              # noop
            else
              node.other_groups = node.other_groups.dup.unshift(group_name)
            end
          end
        end
      end

      def remove(*nodes)
        group_name = model_name_or_error
        nodes = nodes.reject do |node|
          next if Models::Node.exists?(Config.cluster, node)
          Log.warn_puts <<~WARN.squish
            Skipping node '#{node}' as it does not exist
          WARN
          true
        end
        nodes.each do |node_name|
          Models::Node.update(Config.cluster, node_name) do |node|
            node.other_groups = node.other_groups.dup.tap { |g| g.delete(group_name) }
          end
        end
      end
    end
  end
end
