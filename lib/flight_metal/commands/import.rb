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
    class Import

      def initialize
        require 'zip'
        require 'pathname'
        require 'ostruct'

        require 'active_support/core_ext/module/delegation'

        require 'flight_metal/models/node'

        require 'flight_metal/errors'
      end

      def run(path)
        zip_path = Pathname.new(path).expand_path.sub_ext('.zip').to_s
        Importer.extract(zip_path) do |importer|
          importer.nodes.each do |data|
            begin
              model = Models::Node.create_or_update(Config.cluster, data.name) do |node|
                ImportError.raise(node.name) if node.imported?
                data.extract(node.template_dir)
                node.imported = true
                node.rebuild = true
              end
              Log.info_puts "Imported node '#{model.name}'"
            rescue ImportError => e
              Log.error_puts "Skipping: #{e.message}"
            end
          end
        end
      end

      Importer = Struct.new(:zip) do
        NodeStruct = Struct.new(:name, :base) do
          def entries
            @entries ||= []
          end

          def extract(dst_base)
            entries.each do |entry|
              dst = File.join(dst_base, entry.name.sub(base, ''))
              FileUtils.mkdir_p(File.dirname(dst))
              entry.extract(dst)
            end
          end
        end

        PLATFORM_GLOB = 'kickstart/node/*/platform/**/*'
        PLATFORM_REGEX = /\A(?<base>kickstart\/node\/(?<node>[^\/]+)\/platform)\/.*/

        def self.extract(path)
          Zip::File.open(path) do |f|
            yield new(f) if block_given?
          end
        end

        delegate_missing_to :zip

        def nodes
          glob(PLATFORM_GLOB).each_with_object({}) do |entry, memo|
            match = PLATFORM_REGEX.match(entry.name)
            node = match[:node].to_s
            memo[node] ||= NodeStruct.new(node, match[:base])
            memo[node].entries << entry
          end.values
        end
      end
    end
  end
end

