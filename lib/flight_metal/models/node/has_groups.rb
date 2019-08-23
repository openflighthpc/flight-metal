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

require 'active_support/concern'

module FlightMetal
  module Models
    class Node
      module HasGroups
        extend ActiveSupport::Concern

        included do
          data_reader(:primary_group) do |primary|
            primary || begin
              if File.exists? Models::Group.path(cluster, 'orphan')
                'orphan'
              else
                Models::Group.create(cluster, 'orphan').name
              end
            end
          end

          data_writer(:primary_group) do |primary|
            if File.exists? Models::Group.path(cluster, primary)
              primary
            else
              raise InvalidModel, <<~ERROR.chomp
                Can not set the primary group as '#{primary}' does not exist
              ERROR
            end
          end

          data_reader(:other_groups) do |groups|
            groups || []
          end
          data_writer(:other_groups) { |v| v.to_a.uniq }

          define_symlinks(:primary_group) do |link|
            link.path_builder do |cluster, node, group|
              Models::Group.cache_join(cluster, group, 'primary-nodes', node + '.link')
            end

            link.paths do |n|
              [link.path_builder.call(n.cluster, n.name, n.primary_group)]
            end

            link.validate do |n, link_path|
              regex = /#{link.path_builder.call(n.cluster, n.name, '(?<group>.*)')}/
              group = link_path.to_s.match(regex)[:group]
              n.primary_group == group
            end
          end

          define_symlinks(:other_groups) do |link|
            link.path_builder do |cluster, node, group|
              Models::Group.cache_join(cluster, group, 'other-nodes', node + '.link')
            end

            link.paths do |n|
              n.other_groups.map { |g| link.path_builder.call(n.cluster, n.name, g) }
            end

            link.validate do |n, link_path|
              regex = /#{link.path_builder.call(n.cluster, n.name, '(?<group>.*)')}/
              group = link_path.to_s.match(regex)[:group]
              n.groups.include?(group)
            end
          end
        end

        def groups
          [primary_group, *other_groups].uniq
        end

        def read_groups
          groups.map { |n| Models::Group.read(cluster, n, registry: __registry__) }
        end

        def read_other_groups
          other_groups.map { |n| Models::Group.read(cluster, n, registry: __registry__) }
        end

        def read_primary_group
          Models::Group.read(cluster, primary_group, registry: __registry__)
        end
      end
    end
  end
end
