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
    class Edit < ScopedCommand
      command_require 'flight_metal/template_map', 'tty-editor'

      def run(cli_type, replace: nil)
        @type = TemplateMap.lookup_key(cli_type)
        FileUtils.touch path unless model.type_path?(type)
        if replace
          raise MissingFile, <<~DESC.chomp unless File.exists?(replace)
            Can not replace the file as the sources does not exist: #{replace}
          DESC
          FileUtils.cp replace, path
        elsif File.exists? path
          TTY::Editor.open(path)
        else
          raise MissingFile, <<~DESC.chomp
            Can not edit the file as it does not exist: #{path}
          DESC
        end
      end

      private

      attr_reader :type

      def model
        @model ||= read_model.tap(&:__data__)
      end

      def path
        @path ||= Pathname.new(model.type_path(type)).tap do |p|
          FileUtils.mkdir_p p.dirname
        end
      end
    end
  end
end
