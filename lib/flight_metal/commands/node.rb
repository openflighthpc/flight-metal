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
      class NilStruct < OpenStruct
        def initialize
          super(nil)
        end

        def respond_to?(_s)
          true
        end
      end

      class Templator < SimpleDelegator
        def initialize(obj)
          self.__setobj__(obj)
        end

        def render(text)
          ERB.new(text, nil, '-').result(binding)
        end

        def nil_to_null(value)
          value.nil? ? 'null' : value
        end
      end

      LIST_TEMPLATE = <<~ERB
        # Node: '<%= name %>'
        *Imported*: <%= imported? ? imported_time : 'n/a' %>
        *Hunted*: <%= mac? ? mac_time : 'n/a' %>
        *Built*: <%= built? ? built_time : 'n/a' %>
        *Rebuild*: <%= rebuild? ? 'Scheduled': 'n/a' %>

        <% if mac?; %>*MAC*: <%= mac %><% end %>

      ERB

      EDIT_TEMPLATE = <<~ERB
        # NOTE: Editing this file will update the state information of all the nodes.
        # The following conventions are used when editting this file:
        #  > Fields will skip updating if:
        #    1. The field is deleted
        #    2. The key is set to null
        #  > Fields can be unset by passing an empty string (*when supported)

        # Trigger the node to rebuild next build:
        # > #{Config.app_name} build
        rebuild: <%= nil_to_null(rebuild?) %>

        # Flags the built state of the node
        built: <%= nil_to_null(built?) %>

        # Set the bmc username and password
        bmc_username: <%= nil_to_null(bmc_user) %>
        bmc_password: <%= nil_to_null(bmc_password) %>

        <%# DEV NOTE: A NilStruct is used when editting multiple nodes
            This works fine with the above properties as is renders to null,
            and thus skips being set unless changed. However, the properties
            below are unsettable in a bulk edit as they need to unique
        -%>
        <% if __getobj__.is_a? FlightMetal::Commands::Node::NilStruct -%>
        # The hardware and bmc ip addresses can not be set using a bulk edit
        <% else -%>
        # NOTE: The following can be unset with an empty string
        # Set the hardware address (mac) and the bmc ip address (bmc_ip)
        mac: <%= nil_to_null(mac) %>
        bmc_ip: <%= nil_to_null(bmc_ip) %>
        <% end -%>
      ERB

      command_require 'erb',
                      'tty-markdown',
                      'flight_metal/models/node'

      include Concerns::NodeattrParser

      def list
        md = Models::Node.glob_read(Config.cluster, '*')
                         .sort_by { |n| n.name }
                         .map { |n| Templator.new(n).render(LIST_TEMPLATE) }
                         .join("\n")
        puts TTY::Markdown.parse(md)
      end

      def edit(nodes_str)
        nodes = nodeattr_parser(nodes_str)
        yaml = Templator.new(nodes.length == 1 ? nodes.first : NilStruct.new)
                        .render(EDIT_TEMPLATE)
        puts yaml
      end
    end
  end
end
