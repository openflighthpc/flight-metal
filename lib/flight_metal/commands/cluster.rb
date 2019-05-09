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
    class Cluster
      def initialize
        require 'flight_metal/models/cluster'
      end

      def init(identifier)
        cluster = Models::Cluster.create(identifier)
        Config.create_or_update { |c| c.cluster = cluster.identifier }
        puts "Created cluster: #{cluster.identifier}"
      end

      def list
        Config.cluster # Ensures that at least the default cluster exists
        id_strs = Models::Cluster.glob_read('*')
                            .map(&:identifier)
                            .map do |id|
          "#{id == Config.cluster ? '*' : ' '} #{id}"
        end
        puts id_strs.join("\n")
      end

      def switch(identifier)
        cluster = Models::Cluster.read(identifier)
        Config.create_or_update { |c| c.cluster = cluster.identifier }
        puts "Switched cluster: #{cluster.identifier}"
      end
    end
  end
end

