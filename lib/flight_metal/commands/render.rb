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
    class Render < Command
      command_require 'flight_metal/models/cluster',
                      'flight_metal/models/node',
                      'flight_metal/template_map'

      def run(identifier, cli_type,
              force: false, nodes_in: nil, nodes_in_primary: nil)
        # Verify the type
        type = TemplateMap.lookup_key(cli_type)

        # Load the nodes
        nodes = if nodes_in
          read_group(identifier).read_nodes
        elsif nodes_in_primary
          read_group(identifier).read_nodes
        else
          [Models::Node.read(Config.cluster, identifier)]
        end

        # Render for each node
        errors = false
        nodes.each do |node|
          initial = File.read(node.type_template_path(type))
          rendered = node.render_params.reduce(initial) do |memo, (key, value)|
            memo.gsub("%#{key}%", value)
          end
          if !force && /%\w+%/.match?(rendered)
            errors = true
            matches = rendered.scan(/%\w+%/).uniq.sort
                              .map { |s| /\w+/.match(s).to_s }
            Log.error_puts <<~ERROR.squish
              Failed to render #{node.name} #{type}:
              The following parameters have not been replaced:
              #{matches.join(',')}
            ERROR
          else
            dst = node.type_path(type)
            FileUtils.mkdir_p File.dirname(dst)
            File.write(node.type_path(type), rendered)
          end
        end

        # Notify about the erros
        Log.info_puts <<~INFO.squish if errors
          Some templates have failed to render correctly. Use --force to skip
          the error and save anyway
        INFO
      end

      private

      def read_group(group)
        Models::Group.read(Config.cluster, group)
      end
    end
  end
end
