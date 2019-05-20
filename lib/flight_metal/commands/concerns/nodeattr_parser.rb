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

require 'active_support/concern'

module FlightMetal
  module Commands
    module Concerns
      module NodeattrParser
        class NodeArray < DelegateClass(Array)
          def all_exist?
            missing.empty?
          end

          def missing
            self.reject { |n| File.exists?(n.path) }
          end
        end

        extend ActiveSupport::Concern

        included do
          command_require 'nodeattr_utils/node_parser'
          command_require 'flight_metal/models/node'
        end

        def nodeattr_parser(string)
          nodes = NodeattrUtils::NodeParser.expand(string).map do |name|
            FlightMetal::Models::Node.read_or_new(Config.cluster, name)
          end
          NodeArray.new(nodes.sort_by(&:name))
        end
      end
    end
  end
end
