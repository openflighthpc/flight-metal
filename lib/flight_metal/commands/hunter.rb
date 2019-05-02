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
      def run
        setup_network_connection
        $stderr.puts <<~MSG.squish
          Waiting for new nodes to appear on the network, please network boot
          them now...,
        MSG
        $stderr.puts '(Ctrl-C to terminate)'

        network.each_packet do |packet|
          process_packet(packet.udp_data) if packet.udp?
        end
      end

      private

      attr_reader \
        :detected_macs,
        :detection_count,
        :hunter_log,
        :network

      def setup_network_connection
        pcaplet_options = "-s 600 -n -i #{Config.interface}"
        @detected_macs ||= []
        @detection_count ||= 0
        @network ||= Pcaplet.new(pcaplet_options).tap do |network|
          filter_string = 'udp port 67 and udp port 68'
          filter = Pcap::Filter.new(filter_string, network.capture)
          network.add_filter(filter)
        end
      end

      def process_packet(data)
        $stderr.puts 'Processing received UDP packet'
        message = DHCP::Message.from_udp_payload(data, debug: false)
        process_message(message) if message.is_a?(DHCP::Discover)
      end

      def process_message(message)
        $stderr.puts 'Processing DHCP::Discover message options'
        message.options.each do |o|
          detected(hwaddr_from(message)) if pxe_client?(o)
        end
      end

      def hwaddr_from(message)
        $stderr.puts 'Determining hardware address'
        message.chaddr.slice(0..(message.hlen - 1)).map do |b|
          b.to_s(16).upcase.rjust(2, '0')
        end.join(':').tap do |hwaddr|
          $stderr.puts "Detected hardware address: #{hwaddr}"
        end
      end

      def pxe_client?(o)
        o.is_a?(DHCP::VendorClassIDOption) && o.payload.pack('C*').tap do |vend|
          $stderr.puts "Detected vendor: #{vend}"
        end =~ /^PXEClient/
      end

      def detected(hwaddr)
        return if detected_macs.include?(hwaddr)

        detected_macs << hwaddr

        handle_new_detected_mac(hwaddr)
      end

      def previously_hunted?(hwaddr)
        cached_macs_to_nodes.include?(hwaddr)
      end

      def notify_user_of_ignored_mac(hwaddr)
        assigned_node_name = cached_macs_to_nodes[hwaddr]
        message = \
          'Detected already hunted MAC address on network ' \
          "(#{hwaddr} / #{assigned_node_name}); ignoring."
        $stderr.puts message
      end

      def cached_macs_to_nodes
        Models::Node.glob_read(Config.cluster, '*')
                    .reject { |n| n.mac.empty? }
                    .map { |n| [n.mac, n.name] }
                    .to_h
      end

      def handle_new_detected_mac(hwaddr)
        default_name = sequenced_name
        @detection_count += 1

        name_node_question = \
          "Detected a machine on the network (#{hwaddr}). Please enter " \
          'the hostname:'
        name = HighLine.new.ask(name_node_question) do |answer|
          answer.default = default_name
        end
        record_hunted_pair(name, hwaddr)
        $stderr.puts "#{name}-#{hwaddr}"
        $stderr.puts'Logged node'
      rescue StandardError => e
        $stderr.puts"FAIL: #{e.message}"
        retry if HighLine.new.agree('Retry? [yes/no]:')
      end

      def record_hunted_pair(node_name, mac_address)
        Models::Node.create_or_update(Config.cluster, node_name) do |n|
          n.mac = mac_address
        end
      end

      def sequenced_name
        "#{Config.node_prefix}#{detection_count.to_s.rjust(Config.node_index_length, '0')}"
      end
    end
  end
end
