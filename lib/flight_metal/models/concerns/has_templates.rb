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

require 'active_support/concern'
require 'flight_metal/renderer'

module FlightMetal
  module Models
    module Concerns
      module HasTemplates
        extend ActiveSupport::Concern

        def template_path(type, to:)
          TemplateMap.raise_unless_valid_type(type)
          raise_unless_valid_template_target(to)
          build_template_path(type, to: to)
        end

        def template?(*a)
          File.exists? template_path(*a)
        end

        def read_template(*a)
          File.read template_path(*a)
        end

        def renderer(type, source:, to:)
          path = source.template_path(type, to: to)
          Renderer.new(self, path)
        end

        private

        def raise_unless_valid_template_target(_to)
          raise NotImplementedError
        end

        def build_template_path(_type, to:)
          raise NotImplementedError
        end
      end
    end
  end
end

