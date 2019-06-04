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
      MANIFEST_PATH = 'kickstart/manifest.yaml'

      def initialize
        require 'zip'
        require 'pathname'

        require 'flight_metal/models/node'
        require 'flight_metal/errors'
        require 'flight_metal/commands/node'

        require 'tempfile'
      end

      def run(path)
        zip_path = Pathname.new(path).expand_path.sub_ext('.zip').to_s
        Zip::File.open(zip_path) { |z| run_zip(z) }
      end

      private

      def run_zip(zip)
        yaml = zip.read(zip.get_entry(MANIFEST_PATH))
        data = YAML.safe_load(yaml)
        data.each { |*a| add_node(zip, *a.first) }
      end

      def add_node(zip, node, data)
        tmp_ks = Tempfile.new(File.join(node.to_s, 'kickstart'))
        tmp_pxe = Tempfile.new(File.join(node.to_s, 'pxelinux'))
        tmp_ks.write zip.read(data['kickstart_file'])
        tmp_ks.flush
        data['kickstart_file'] = tmp_ks.path
        tmp_pxe.write zip.read(data['pxelinux_file'])
        tmp_pxe.flush
        data['pxelinux_file'] = tmp_pxe.path
        Commands::Node.new.create(node.to_s, fields: YAML.dump(data))
        Log.info_puts "Imported: #{node.to_s}"
      rescue => e
        Log.error_puts "Failed to import node: #{node.to_s}"
        Log.error_puts e
      ensure
        tmp_ks.tap(&:close).tap(&:unlink)
        tmp_pxe.tap(&:close).tap(&:unlink)
      end
    end
  end
end

