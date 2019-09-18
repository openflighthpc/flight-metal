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
# For more information on flight-metal, please visit:
# https://github.com/alces-software/flight-metal
#===============================================================================

module FlightMetal
  module Commands
    class List < ScopedCommand
      def nodes
        nodes = read_nodes
        puts nodes.map(&:name)
        nodes.each(&:generate_indices)
      end

      def groups
        groups = read_groups
        puts groups.map(&:name)
        groups.each(&:generate_indices)
      end

      def clusters
        Config.cluster # Ensures that at least the default cluster exists
        clusters = Models::Cluster.glob_read('*')
        id_strs = clusters.map(&:identifier).map do |id|
          "#{id == Config.cluster ? '*' : ' '} #{id}"
        end
        puts id_strs.join("\n")
        clusters.each(&:generate_indices)
      end
    end
  end
end
