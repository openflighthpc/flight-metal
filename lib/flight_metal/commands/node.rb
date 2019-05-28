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
      LIST_TEMPLATE = <<~ERB
        # Node: '<%= name %>'
        *Imported*: <%= imported? ? imported_time : 'n/a' %>
        *Hunted*: <%= mac? ? mac_time : 'n/a' %>
        <% if built? -%>
        *Built*: <%= built_time %>
        *Rebuild*: <%= rebuild? ? 'Scheduled': 'n/a' %>
        <% else  -%>
        *Build*: <%= rebuild? ? 'Scheduled' : 'Skipping' %>
        <% end -%>

        *IP*: <%= catch_error { ip } %>
        *Domain Name*: <%= catch_error { fqdn } %>

        <% if mac? %>*MAC*: <%= mac %><% end %>
        <% if bmc_username %>*BMC Username*: <%= bmc_username %><% end %>
        <% if bmc_password %>*BMC Password*: <%= bmc_password %><% end %>
        <% if bmc_ip %>*BMC IP*: <%= bmc_ip %><% end %>
      ERB

      MULTI_EDITABLE = [:rebuild, :built, :bmc_username, :bmc_password]
      SINGLE_EDITABLE = [*MULTI_EDITABLE, :mac, :bmc_ip]

      EDIT_TEMPLATE = <<~ERB
        # NOTE: Editing this file will update the state information of all the nodes.
        # The following conventions are used when editing:
        #  > Fields will skip updating if:
        #    1. The field is deleted
        #    2. The value is set to null
        #  > Fields can be unset by passing an empty string (*when supported)
        #  > Use the --fields flag to edit in a non-interactive shell
        #  > Only the listed fields can be edited

        # Trigger the node to rebuild next build:
        # > #{Config.app_name} build
        rebuild: <%= nil_to_null(rebuild?) %>

        # Flags the built state of the node
        built: <%= nil_to_null(built?) %>

        # Set the bmc username and password
        bmc_username: <%= nil_to_null(bmc_user) %>
        bmc_password: <%= nil_to_null(bmc_password) %>

        <%# DEV NOTE: A NilStruct is used when editing multiple nodes
            This works fine with the above properties as is renders to null,
            and thus skips being set unless changed. However, the properties
            below are unsettable in a bulk edit as they need to unique
        -%>
        <% if __getobj__.is_a? FlightMetal::Templator::NilStruct -%>
        # The hardware and bmc ip addresses can not be set using a bulk edit
        # mac: IGNORED
        # bmc_ip: IGNORED
        <% else -%>
        # NOTE: The following can be unset with an empty string
        # Set the hardware address (mac) and the bmc ip address (bmc_ip)
        mac: <%= nil_to_null(mac) %>
        bmc_ip: <%= nil_to_null(bmc_ip) %>
        <% end -%>
      ERB

      command_require 'flight_metal/models/node',
                      'flight_metal/templator'

      include Concerns::NodeattrParser

      def list
        md = Registry.new
                     .glob_read(Models::Node, Config.cluster, '*')
                     .sort_by { |n| n.name }
                     .map { |n| Templator.new(n).markdown(LIST_TEMPLATE) }
                     .join
        puts md
      end

      def edit(nodes_str, fields: nil)
        nodes = nodeattr_parser(nodes_str)
        nodes.raise_if_missing
        if nodes.length == 1
          edit_single(nodes.first, fields)
        else
          edit_multiple(nodes, fields)
        end
      end

      private

      def edit_single(node, fields)
        values = read_edit_yaml(node, fields)
        update_node(node, SINGLE_EDITABLE, values)
      end

      def edit_multiple(nodes, fields)
        values = read_edit_yaml(nil, fields)
        nodes.each { |n| update_node(n, MULTI_EDITABLE, values) }
      end

      def read_edit_yaml(subject, fields)
        fields ||= Templator.new(subject).edit(EDIT_TEMPLATE)
        YAML.safe_load(fields, symbolize_names: true)
      end

      def update_node(node, allowed_fields, hash)
        hash = hash.reject do |key, value|
          next true unless allowed_fields.include?(key)
          next true if value.nil?
          next true if node.send(key) == value
        end
        return if hash.empty?
        Models::Node.update(Config.cluster, node.name) do |n|
          hash.each do |key, value|
            n.send("#{key}=", value)
          end
        end
      end
    end
  end
end
