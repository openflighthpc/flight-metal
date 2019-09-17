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
    class FileCommand < ScopedCommand
      command_require 'flight_metal/template_map',
                      'flight_metal/models/node',
                      'tty-editor'

      def add(cli_type, rel_path)
        path = File.expand_path(rel_path)
        runner(cli_type, missing: true) do |_a, _b, dst_path|
          FileUtils.mkdir_p File.dirname(dst_path)
          FileUtils.cp path, dst_path
        end
      end

      def remove(cli_type)
        runner(cli_type) do |_a, _b, path|
          FileUtils.rm_f path
        end
      end

      def touch(cli_type)
        runner(cli_type, missing: true) do |_a, _b, dst_path|
          FileUtils.mkdir_p File.dirname(dst_path)
          FileUtils.touch dst_path
        end
      end

      def show(cli_type)
        runner(cli_type) { |m, t| puts m.read_file(t) }
      end

      def edit(cli_type)
        runner(cli_type) do |_a, _b, dst_path|
          TTY::Editor.open(dst_path)
        end
      end

      def source(cli_type)
        model = read_model
        type = TemplateMap.lookup_key(cli_type)
        if model.source?(type)
          source = model.source_model(type)
          level = case source
                  when Models::Node
                    'Node'
                  when Models::Cluster
                    'Cluster'
                  else
                    raise InternalError, 'An unexpected error has occurred'
                  end
          puts "Level: #{level}"
          puts " Name: #{source.is_a?(Models::Node) ? source.name : '-'}"
          puts " Path: #{model.source_path(type)}"
        else
          Log.warn_puts "Could not locate a #{cli_type} source template for #{model.name}"
        end
      end

      def render(cli_type)
        runner(cli_type) do |model, type|
          if model.source?(type)
            puts model.renderer(type).rendered
          else
            Log.warn_puts "Could not locate a #{cli_type} source template for #{model.name}"
          end
        end
      end

      private

      def deployable_type
        if model_class == Models::Machine
          :machine
        else
          raise InternalError, 'an unexpected error has occurred'
        end
      end

      def runner(cli_type, missing: false)
        type = TemplateMap.lookup_key(cli_type)
        model = read_model
        has_file = model.file?(type)

        if has_file && missing
          raise InvalidAction, <<~ERROR.chomp
            Can not continue as the #{cli_type} file already exists
          ERROR
        elsif has_file || missing
          path = model.file_path(type)
          yield model, type, path if block_given?
        else
          raise InvalidAction, <<~ERROR.chomp
            '#{model_name_or_error}' does not have a #{cli_type} file
          ERROR
        end
      end
    end
  end
end
