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
    class ListNodes < ScopedCommand
      class ListDelegator < SimpleDelegator
        attr_reader :sys_ip, :sys_fqdn, :verbose

        def initialize(node, fqdn: nil, ip: nil, verbose: nil)
          super(node)
          @sys_ip = sys_ip
          @sys_fqdn = sys_fqdn
          @verbose = verbose
        end
      end

      LIST_TEMPLATE = <<~ERB
        # Node: '<%= name %>'
        *Built*: <%= built? ? built_time : 'Never' %>
        *<%= built? ? 'Reb' : 'B' %>uild*: <%= if buildable?
                                                 'Scheduled'
                                               elsif rebuild?
                                                 'Skipping'
                                               else
                                                 'No'
                                               end %>

        <% first_status = true -%>
        <% FlightMetal::TemplateMap.flag_hash.each do |type, flag| -%>
        <%
             status = type_status(type, error: false)
             text = case status
                    when :invalid
                      'Invalid - check link: ' + type_system_path(type)
                    else
                      status.capitalize
                    end
        -%>
        <%   if verbose || ![:pending, :installed].include?(status) -%>
        <%=
               if first_status
                 first_status = false
                 '## File Status'
               end
        %>
        - *<%= flag %>*: <%= text %>
        <%   end -%>
        <% end -%>

        <% if verbose -%>
        ## File Template Source
        <%   FlightMetal::TemplateMap.flag_hash.each do |type, flag| -%>
        <%
               bool = type_template_model(type).is_a?(FlightMetal::Models::Cluster)
               source = (bool ? 'Domain' : "Primary Group")
        -%>
        - *<%= flag %>*: <%=
          case type_template_model(type)
          when FlightMetal::Models::Cluster
            'Domain'
          when FlightMetal::Models::Group
            'Primary Group'
          else
            'Missing'
          end
        %>
        <%   end -%>
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

      command_require('flight_metal/buildable_nodes', 'flight_metal/templator')

      def shared(verbose: nil)
        nodes = read_nodes.sort_by(&:name)
        delegets = nodes.each_with_index.map do |node, idx|
          ListDelegator.new(node, verbose: verbose)
        end
        md = delegets.map { |n| Templator.new(n).markdown(LIST_TEMPLATE) }
                     .join
        puts md
      end
    end
  end
end


