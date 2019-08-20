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
    class Render < ScopedCommand
      command_require 'flight_metal/template_map', 'flight_metal/models/group'

      def groups(cli_type)
        # TODO: Implement this as `read_groups` on the Command base clase
        models = [Models::Group.read(Config.cluster, model_name_or_error)]
        shared(cli_type, models)
      end

      def nodes(cli_type, force: false)
        # Load the nodes as the models
        models = read_nodes
        shared(cli_type, models, force: force)
      end

      private

      def shared(cli_type, models, force: true)
        type = TemplateMap.lookup_key(cli_type)

        # Reject those without a template
        models.reject! do |model|
          next if model.type_template_path?(type)
          Log.warn_puts "Skipping #{model.name}: Can not locate a template"
          true
        end

        # Render each model
        errors = false
        models.each do |model|
          initial = File.read(model.type_template_path(type))
          rendered = model.params.reduce(initial) do |memo, (key, value)|
            prefix = case model
                     when Models::Node; 'node'
                     when Models::Group; 'group'
                     else; raise InternalError
                     end
            memo.gsub("%#{key}%", value.to_s)
                .gsub("%#{prefix}.#{key}%", value.to_s)
          end
          if !force && /%\w+%/.match?(rendered)
            errors = true
            matches = rendered.scan(/%\w+%/).uniq.sort
                              .map { |s| /\w+/.match(s).to_s }
            Log.error_puts <<~ERROR.squish
              Failed to render #{model.name} #{type}:
              The following parameters have not been replaced:
              #{matches.join(',')}
            ERROR
          else
            dst = model.type_path(type)
            FileUtils.mkdir_p File.dirname(dst)
            File.write(model.type_path(type), rendered)
            Log.info_puts "Rendered #{model.name}: #{dst}"
          end
        end

        # Notify about errors
        Log.info_puts <<~INFO.squish if errors
          Some templates have failed to render correctly. Use --force to skip
          the error(s) and save anyway
        INFO
      end
    end
  end
end
