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
    class Template < ScopedCommand
      command_require 'flight_metal/template_map',
                      'tty-editor'

      def add(cli_type, rel_path)
        path = File.expand_path(rel_path)
        runner(cli_type, missing: true) do |model, type|
          dst_path = model.template_path(type)
          FileUtils.mkdir_p File.dirname(dst_path)
          FileUtils.cp path, dst_path
        end
      end

      def remove(cli_type)
        runner(cli_type) do |model, type|
          FileUtils.rm_f model.template_path(type)
        end
      end

      def touch(cli_type)
        runner(cli_type, missing: true) do |model, type|
          dst_path = model.template_path(type)
          FileUtils.mkdir_p File.dirname(dst_path)
          FileUtils.touch dst_path
        end
      end

      def show(cli_type)
        runner(cli_type) { |m, t| puts m.read_template(t) }
      end

      def edit(cli_type)
        runner(cli_type) do |model, type|
          TTY::Editor.open(model.template_path(type))
        end
      end

      def render(cli_type)
        runner(cli_type) do |model, type|
          puts model.renderer(type).rendered
        end
      end

      private

      def runner(cli_type, missing: false)
        type = TemplateMap.lookup_key(cli_type)
        model = read_model
        has_template = model.template?(type)

        if has_template && missing
          raise InvalidAction, <<~ERROR.chomp
            Can not continue as the #{cli_type} template already exists
          ERROR
        elsif has_template || missing
          yield model, type if block_given?
        else
          raise InvalidAction, <<~ERROR.chomp
            '#{model_name_or_error}' does not have a #{cli_type} source template
          ERROR
        end
      end
    end
  end
end
