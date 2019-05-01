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

require 'zip'
require 'pathname'
require 'ostruct'

require 'active_support/core_ext/module/delegation'

require 'flight_metal/models/node'

module FlightMetal
  module Commands
    class Import
      def run(path)
        zip_path = Pathname.new(path).expand_path.sub_ext('.zip').to_s
        Importer.extract(zip_path) do |importer|
          nodes_hash = importer.node_entries
          nodes_hash.each do |name, data|
            begin
              model = Models::Node.create(Config.cluster, name.to_s) do |node|
                data.entries.each do |entry|
                  dst = File.join(
                    node.template_dir,
                    entry.name.sub(data.base, '')
                  )
                  FileUtils.mkdir_p(File.dirname(dst))
                  entry.extract(dst)
                end
              end
              puts "Imported node '#{model.name}'"
            rescue FlightConfig::CreateError
              $stderr.puts <<~ERROR
                Skipping import of node '#{name}' as it already exists
              ERROR
            end
          end
        end
      end

      Importer = Struct.new(:zip) do
        PLATFORM_GLOB = 'kickstart/node/*/platform/**/*'
        PLATFORM_REGEX = /\A(?<base>kickstart\/node\/(?<node>[^\/]+)\/platform)\/.*/

        def self.extract(path)
          Zip::File.open(path) do |f|
            yield new(f) if block_given?
          end
        end

        delegate_missing_to :zip

        def node_entries
          glob(PLATFORM_GLOB).each_with_object({}) do |entry, memo|
            match = PLATFORM_REGEX.match(entry.name)
            node = match[:node].to_sym
            memo[node] ||= OpenStruct.new(base: match[:base], entries: [])
            memo[node].entries << entry
          end
        end
      end
    end
  end
end

