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
  class FlightMetalError < StandardError; end

  class ImportError < FlightMetalError
    def self.raise(name)
      Kernel.raise self, <<~ERROR
        Node '#{name}' has already been imported
      ERROR
    end
  end

  class BadMessageError < FlightMetalError
    MESSAGE = 'Cannot parse message body, ensure it is JSON and not truncated'

    def initialize(msg = MESSAGE)
      super
    end
  end

  class SystemCommandError < FlightMetalError; end
  class InternalError < FlightMetalError; end
  class InvalidInput < FlightMetalError; end
end


