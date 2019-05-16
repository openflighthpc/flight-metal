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

require 'socket'

require 'flight_metal/server/message'

module FlightMetal
  class Server
    attr_reader :host, :port, :max_size

    def initialize(host, port, max_size)
      @host = host
      @port = port
      @max_size = max_size
    end

    def socket
      @socket ||= UDPSocket.new.tap do |soc|
        soc.bind(host, port)
      end
    end

    def loop
      Log.info_puts "Listening on port: #{port}"
      return unless block_given?
      while res = socket.recvfrom(max_size)
        message = Message.new(res)
        begin
          message.body
        rescue BadMessageError => e
          Log.error(e.message)
          next
        end
        return unless yield message
      end
    end
  end
end

