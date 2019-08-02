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

require 'ostruct'
require 'flight_metal/commands/concerns/nodeattr_parser'

module FlightMetal
  module Commands
    class Node < Command
      class SysIPDelegator < SimpleDelegator
        attr_reader :sys_ip, :sys_fqdn

        def initialize(node, sys_fqdn = nil, sys_ip = nil)
          super(node)
          @sys_ip = sys_ip
          @sys_fqdn = sys_fqdn
        end
      end

      LIST_TEMPLATE = <<~ERB
        # Node: '<%= name %>'
        *Hunted*: <%= mac? ? mac_time : 'n/a' %>
        <% if built? -%>
        *Built*: <%= built_time %>
        *Rebuild*: <%= rebuild? ? 'Scheduled': 'n/a' %>
        <% else  -%>
        *Build*: <%= rebuild? ? 'Scheduled' : 'Skipping' %>
        <% end -%>

        *Primary Group*: <%= primary_group || 'n/a' %>
        <% sg = secondary_groups -%>
        *Secondary Groups*: <%= sg.empty? ? 'n/a' : sg.join(',') %>

        ## File Status
        <% FlightMetal::TemplateMap.flag_hash.each do |type, flag| -%>
        - *<%= flag %>*: <%= public_send(type.to_s + '_status', error: false).capitalize %>
        <% end -%>

        ## Reserved Parameters
        <% reserved_params.each do |key, value| -%>
        - _<%= key %>_: <%= value %>
        <% end -%>

        <% unless params.empty? -%>
        ## Other Parameters
        <%   params.each do |key, value| -%>
        - *<%= key %>*: <%= value %>
        <%   end -%>
        <% end -%>

      ERB

      command_require 'flight_metal/models/node',
                      'flight_metal/templator',
                      'flight_metal/system_command'

      include Concerns::NodeattrParser

      def update(name, *params)
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
        end
      end

      def list
        nodes = Models::Node.glob_read(Config.cluster, '*')
                            .sort_by { |n| n.name }
        outputs = SystemCommand.new(*nodes).fqdn_and_ip
        sys_nodes = nodes.each_with_index
                         .map do |node, idx|
          SysIPDelegator.new(node, *outputs[idx].stdout.split)
        end
        md = sys_nodes.map { |n| Templator.new(n).markdown(LIST_TEMPLATE) }
                      .join
        puts md
      end

      def delete(name)
        Models::Node.delete!(Config.cluster, name)
      end
    end
  end
end
