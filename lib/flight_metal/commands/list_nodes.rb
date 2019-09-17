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
        attr_reader :verbose

        def initialize(node, fqdn: nil, ip: nil, verbose: nil)
          super(node)
          @verbose = verbose
        end
      end

      LIST_TEMPLATE = <<~ERB
        <% machine = read_machine -%>
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
        ## File Status
        <%  FlightMetal::TemplateMap.flag_hash.each do |type, flag|
              ready_status = machine.file?(type) ? 'Ready' : 'Missing'
              is_updatable = machine.source?(type)
        -%>
        - *<%= flag %>*: <%= ready_status %> <%= '(Updatable)' if is_updatable %>
        <%  end -%>

        <%  if verbose -%>
        ## Template Source
        <%    FlightMetal::TemplateMap.flag_hash.each do |type, flag| -%>
        - *<%= flag %>*: <%=
          case machine.source_model(type)
          when FlightMetal::Models::Cluster
            'Cluster'
          when FlightMetal::Models::Group
            'Primary Group'
          when FlightMetal::Models::Node
            'Node'
          else
            'Missing'
          end
        %>
        <%    end -%>
        <%  end -%>


        ## Reserved Parameters
        <% reserved_params.each do |key, value| -%>
        - _<%= key %>_: <%= value %>
        <% end -%>

        <% unless non_reserved_params.empty? -%>
        ## Other Parameters
        <%   non_reserved_params.each do |key, value| -%>
        - *<%= key %>*: <%= value %>
        <%   end -%>
        <% end -%>

      ERB

      command_require('flight_metal/buildable_nodes', 'flight_metal/templator')

      def shared_verbose
        shared(verbose: true)
      end

      def shared(verbose: nil)
        nodes = read_nodes.sort_by(&:name)

        # HACK: Insure all the indices have been generated, is a backup in case
        # the file was manually edited
        nodes.each(&:generate_indices)

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


