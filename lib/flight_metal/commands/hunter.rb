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

require 'net/dhcp'
require 'pcap'
require 'highline'

module FlightMetal
  module Commands
    class Hunter
      PacketReader = Struct.new(:packet) do
        def message
          @message ||= DHCP::Message.from_udp_payload(packet.udp_data, debug: false)
        end

        def udp?
          packet.udp?
        end

        def dhcp_discover?
          return false unless udp?
          message.is_a?(DHCP::Discover)
        end

        def pxe_request?
          return false unless dhcp_discover?
          $stderr.puts 'Processing DHCP::Discover message options'
          pxe = message.options.find do |opt|
            next unless opt.is_a?(DHCP::VendorClassIDOption)
            vendor = opt.payload.pack('C*')
            $stderr.puts "Detected vendor: #{vendor}"
            /^PXEClient/.match?(vendor)
          end
          pxe ? true : false
        end

        def mac
          message.chaddr.slice(0..(message.hlen - 1)).map do |b|
            b.to_s(16).upcase.rjust(2, '0')
          end.join(':').tap do |hwaddr|
            $stderr.puts "Detected hardware address: #{hwaddr}"
          end
        end
      end

      def run
        macs_to_nodes
        $stderr.puts <<~MSG.squish
          Waiting for new nodes to appear on the network, please network boot
          them now...,
        MSG
        $stderr.puts '(Ctrl-C to terminate)'

        network.each_packet do |packet|
          reader = PacketReader.new(packet)
          detected(reader.mac) if reader.pxe_request?
        end
      end

      private

      def network
        @network ||= begin
          Pcaplet.new("-s 600 -n -i #{Config.interface}").tap do |net|
            net.add_filter(
              Pcap::Filter.new('udp port 67 and udp port 68', net.capture)
            )
          end
        end
      end

      def detected_macs
        @detected_macs ||= []
      end

      def macs_to_nodes
        @macs_to_nodes ||= Models::Node.glob_read(Config.cluster, '*')
          .reject { |n| n.mac.nil? }
          .each_with_object({}) do |node, memo|
            raise <<~ERROR.squish if memo[node.mac]
              Nodes '#{memo[node.mac].name}' and '#{node.name}' have duplicate
              hardware addresses.
            ERROR
            memo[node.mac] = node
          end
      end

      def detected(hwaddr)
        if detected_macs.include?(hwaddr)
          $stderr.puts "Skipping repeated address: #{hwaddr}"
          return
        end
        other_node = macs_to_nodes[hwaddr]

        question = <<~QUESTION.squish
          Detected a machine on the network (#{hwaddr}).
          Please enter the hostname:
        QUESTION
        name = HighLine.new.ask(question) do |q|
          q.default = other_node&.name || sequenced_name
        end

        unless (other_node.nil? || other_node.name == name)
          $stderr.puts "Unassigning address #{hwaddr} from: #{other_node.name}"
          Models::Node.update(Config.cluster, other_node.name) do |n|
            n.mac = nil
          end
          macs_to_nodes[hwaddr] = nil
        end

        node = Models::Node.create_or_update(Config.cluster, name) do |n|
          n.mac = hwaddr
        end

        detected_macs << hwaddr
        macs_to_nodes[node.mac] = node

        $stderr.puts "#{name}-#{hwaddr}"
        $stderr.puts'Logged node'
      rescue StandardError => e
        $stderr.puts"FAIL: #{e.message}"
        retry if HighLine.new.agree('Retry? [yes/no]:')
      end

      def sequenced_name
        Config.node_prefix + \
          detected_macs.length.to_s.rjust(Config.node_index_length, '0')
      end
    end
  end
end
