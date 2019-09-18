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
    class Miscellaneous < ScopedCommand
      def switch_cluster
        cluster = Models::Cluster.read(model_name_or_error).tap(&:__data__)
        Config.create_or_update { |c| c.cluster = cluster.identifier }
        puts "Switched cluster: #{cluster.identifier}"
      end

      def list_clusters
        Config.cluster # Ensures that at least the default cluster exists
        id_strs = Models::Cluster.glob_read('*').map(&:identifier).map do |id|
          "#{id == Config.cluster ? '*' : ' '} #{id}"
        end
        puts id_strs.join("\n")
      end

      LIST_GROUPS = <<~ERB
        # Group: <%= name %>

        ## File Status
        <% FlightMetal::TemplateMap.flag_hash.each do |type, flag| -%>
        - *<%= flag %>*: <%= type_status(type).capitalize %>
        <% end -%>

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
      def list_groups
        require 'flight_metal/templator'
        list = read_groups.sort_by(&:name)
                          .map { |g| Templator.new(g).markdown(LIST_GROUPS) }
                          .join
        puts list
      end

      def cat(cli_type, template: false)
        require 'flight_metal/template_map'
        type = TemplateMap.lookup_key(cli_type)
        path = read_model.send(template ? :type_template_path : :type_path, type)
        if File.exists?(path)
          print File.read(path)
        else
          raise InvalidInput, <<~ERROR.chomp
            Could not locate file: #{path}
          ERROR
        end
      end
    end
  end
end

