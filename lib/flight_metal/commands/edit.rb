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
    class Edit < Command
      command_require 'flight_metal/models/cluster',
                      'flight_metal/models/node',
                      'flight_metal/template_map',
                      'tty-editor'

      def run(type, identifier)
        @type = type
        @identifier = identifier
        if File.exists? path
          TTY::Editor.open(path)
        else
          raise MissingFile, <<~DESC.chomp
            Can not edit the file as it does not exist: #{path}
          DESC
        end
      end

      private

      attr_reader :identifier, :type

      def key
        TemplateMap.lookup_key(@type)
      end

      def model
        @model ||= if identifier == 'domain'
          Models::Cluster.read(Config.cluster)
        else
          raise NotImplementedError
        end
      end

      def path_method
        if model.is_a?(Models::Node)
          raise NotImplementedError
        else
          TemplateMap.template_path_method(key)
        end
      end

      def path
        model.public_send(path_method)
      end
    end
  end
end
