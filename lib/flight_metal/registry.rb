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

require 'flight_metal/errors'

module FlightMetal
  module FlightConfigRegistry
    def __registry__=(reg)
      raise InternalError, <<~ERROR unless reg.is_a?(Registry)
        The model __registry__ must be a FlightMetal::Registry
      ERROR
      @__registry__ = reg
    end

    def __registry__
      @__registry__ ||= Registry.new
    end

    def __read__(*a)
      __registry__.read(*a)
    end
  end


  class Registry
    def read(klass, *args)
      class_hash = (cache[klass] ||= {})
      arity_hash = (class_hash[args.length] ||= {})
      last_arg = args.pop
      last_hash = args.reduce(arity_hash) { |hash, arg| hash[arg] ||= {} }
      last_hash[last_arg] ||= first_read(klass, *args, last_arg)
    end

    private

    def cache
      @cache ||= {}
    end

    def first_read(klass, *args)
      klass.read(*args).tap do |model|
        model.__registry__ = self if model.respond_to?(:"__registry__=")
      end
    end
  end
end
