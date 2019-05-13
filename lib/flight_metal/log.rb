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

require 'logger'
require 'flight_metal/config'

module FlightMetal
  class Log < DelegateClass(Logger)
    class << self
      def logger
        @logger ||= new
      end

      delegate_missing_to :logger
    end

    def initialize
      FileUtils.mkdir_p(File.dirname(Config.log_path))
      super(Logger.new(Config.log_path))
    end

    def warn_puts(msg)
      $stderr.puts msg
      warn(msg)
    end

    def info_puts(msg)
      puts msg
      info(msg)
    end

    def error_puts(msg)
      $stderr.puts msg
      error(msg)
    end
  end
end

FlightConfig.logger = FlightMetal::Log.logger

