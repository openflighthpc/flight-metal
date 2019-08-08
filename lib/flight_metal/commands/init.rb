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
    class Init < Command
      command_require 'flight_metal/models/cluster', 'flight_metal/template_map', 'flight_metal/models/node'

      def run(identifier, **kwargs)
        new_cluster = Models::Cluster.create(identifier) do |cluster|
          save_files(cluster, **kwargs)
        end
        Config.create_or_update do |config|
          config.cluster = new_cluster.identifier
        end
      end

      def node(identifier, **kwargs)
        Models::Node.create(Config.cluster, identifier) do |node|
          save_files(node, **kwargs)
          node.rebuild = true
        end
      end

      private

      def save_files(model, **kwargs)
        saved = []
        TemplateMap.keys.each do |key|
          next unless src = kwargs[key]
          path = model.type_path(key)
          path.dirname.mkdir unless path.dirname.directory?
          FileUtils.cp src, path
          saved << path
        end
      # Clean up the saved files in the event of an error
      rescue Interrupt, StandardError => e
        saved.each { |s| FileUtils.rm s }
        raise e
      end
    end
  end
end
