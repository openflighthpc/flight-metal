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

require 'active_support/core_ext/module/delegation'
require 'hashie/trash'

module FlightMetal
  class Server
    class Message
      class Properties < Hashie::Trash

        def self.safe_load(data)
          data = YAML.safe_load(data)
          raise BadMessageError, <<~ERROR.squish unless data.is_a?(Hash)
            Can not parse message as it is of class '#{data.class}' instead of
            'Hash'.
          ERROR
          new(**data.symbolize_keys)
        rescue Psych::SyntaxError
          raise BadMessageError
        rescue ArgumentError, NoMethodError => e
          raise BadMessageError, <<~ERROR
            Failed to parse the message with the following error:
            #{e.message}
          ERROR
        end

        property :node, required: true
        property :built?,
                 from: :built,
                 default: false,
                 transform_with: ->(v) { v ? true : false }
      end

      MetaData = Struct.new(:type, :port, :hostname, :ip)

      attr_reader :metadata, :raw_body
      delegate_missing_to :body

      def initialize(response)
        @metadata = MetaData.new(*response[1])
        @raw_body = response[0]
      end

      def body
        @body ||= Properties.safe_load(raw_body)
      end

      def to_h
        { metadata: metadata.to_h, body: body.to_h }
      end

      def to_s
        to_h.to_s
      end
    end
  end
end

