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

      def run(type, identifier)
        @type = type
        @identifier = identifier
        initial = File.read(template_path)
        rendered = node.params.reduce(initial) do |memo, (key, value)|
          memo.gsub("%#{key}%", value)
        end
        puts rendered
      end

      private

      attr_reader :type, :identifier

      def key
        TemplateMap.lookup_key(type)
      end

      def node
        @node ||= Models::Node.read(Config.cluster, identifier).tap(&:__data__)
      end

      def template_path
        node.public_send(TemplateMap.template_path_method(key)).tap do |path|
          raise MissingFile, <<~ERROR.chomp unless File.exists?(path)
            Can not render the file as the source does not exist: #{path}
          ERROR
        end
      end

      def rendered_path
        node.public_send(TemplateMap.rendered_path_method(key)).tap do |path|
          FileUtils.mkdir_p(File.dirname(path))
        end
      end
    end
  end
end
