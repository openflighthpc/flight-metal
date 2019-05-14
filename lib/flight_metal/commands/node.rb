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
    class Node
      TEMPLATE = <<~ERB
        # Node: '<%= name %>'
        *Imported*: <%= imported? ? imported_time : 'n/a' %>
        *Hunted*: <%= mac? ? mac_time : 'n/a' %>
        *Built*: <%= built? ? built_time : 'n/a' %>
        *Rebuild*: <%= rebuild? ? 'Scheduled': 'n/a' %>

        <% if mac?; %>*MAC*: <%= mac %><% end %>

      ERB

      def initialize
        require 'erb'
        require 'tty-markdown'
        require 'flight_metal/models/node'
      end

      def list
        renderer = ERB.new(TEMPLATE, nil, '-')
        md = Models::Node.glob_read(Config.cluster, '*')
                         .sort_by { |n| n.name }
                         .map { |n| renderer.result(n.get_binding) }
                         .join("\n")
        puts TTY::Markdown.parse(md)
      end
    end
  end
end
