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

require 'ostruct'
require 'flight_metal/commands/concerns/nodeattr_parser'

module FlightMetal
  module Commands
    class Node < Command
      class SysIPDelegator < SimpleDelegator
        attr_reader :sys_ip, :sys_fqdn

        def initialize(node, sys_fqdn = nil, sys_ip = nil)
          super(node)
          @sys_ip = sys_ip
          @sys_fqdn = sys_fqdn
        end
      end

      LIST_TEMPLATE = <<~ERB
        # Node: '<%= name %>'
        *Hunted*: <%= mac? ? mac_time : 'n/a' %>
        <% if built? -%>
        *Built*: <%= built_time %>
        *Rebuild*: <%= rebuild? ? 'Scheduled': 'n/a' %>
        <% else  -%>
        *Build*: <%= rebuild? ? 'Scheduled' : 'Skipping' %>
        <% end -%>

        *IP*: <%= ip %>
        <% if ip && sys_ip.nil? -%>
        __Warning__: The node IP does not appear in the hosts list
        <% elsif ip != sys_ip -%>
        __Warning__: The node IP is different in the hosts list: <%= sys_ip %>
        <% end -%>
        *Domain Name*: <%= fqdn %>
        <% if fqdn && sys_fqdn.nil? -%>
        __Warning__: The domain name does not appear in the hosts list
        <% elsif fqdn != sys_fqdn -%>
        __Warning__: The domain name is different in the hosts list: <%= sys_fqdn %>
        <% end -%>
        *Gateway*: <%= gateway_ip %>

        <% if mac? %>*MAC*: <%= mac %><% end %>
        <% if bmc_username %>*BMC Username*: <%= bmc_username %><% end %>
        <% if bmc_password %>*BMC Password*: <%= bmc_password %><% end %>
        <% if bmc_ip %>*BMC fqdn*: <%= bmc_ip %><% end %>

      ERB

      HEADER_COMMENT = <<~DOC
        # NOTE: Editing this file will set the state information of the node(s).
        # The following conventions are used when editing:
        #  > Fields will skip updating if:
        #    1. The field is deleted
        #    2. The value is set to null
        #  > Fields can be unset by passing an empty string (*when supported)
        #  > Use the --fields flag to edit in a non-interactive shell
        #  > Only the listed fields can be edited
      DOC

      MULTI_EDITABLE = [
        :rebuild, :built, :bmc_username, :bmc_password, :gateway_ip, :groups
      ]
      SINGLE_EDITABLE = [*MULTI_EDITABLE, :mac, :bmc_ip, :ip, :fqdn]

      # NOTE: This template is rendered against the Models::Node::Builder so
      # the syntax will vary slightly
      CREATE_TEMPLATE = <<~ERB
        #{HEADER_COMMENT}

        # Give the paths to the pxelinux and kickstart files. These files are
        # required for the build and must be given on create. The files will
        # be internally cached, so future changes to the source files will not
        # affect the build
        pxelinux_file: <%= pxelinux_file if pxelinux_file %>
        kickstart_file: <%= kickstart_file if kickstart_file %>

        # Set the primary and secondary groups
        primary_group: <%= nil_to_null(primary_group) %>
        secondary_groups: <%=
          "# Add secondary groups as an array" if secondary_groups.empty?
        %>
        <% if secondary_groups; secondary_groups.each do |group| -%>
          - <%= group %>
        <% end; end -%>

        # Set the primary network ip and fully qualified domain name. The
        # pre-set values (if present) have been retrieved using `gethostip`.
        # Only the cached values will be used to render the DHCP config
        ip: <%= nil_to_null ip %>
        fqdn: <%= nil_to_null fqdn %>

        # Set the management ip address to preform ipmi/power commands
        bmc_ip: <%= nil_to_null bmc_ip %>

        # The hardware address can optional be set now or with the 'hunt'
        # command later
        # mac: null

        <% cluster_model = registry.read(FlightMetal::Models::Cluster, cluster) -%>
        # Override the default bmc username/ password and gateway ip.
        # Uncomment the fields to hard set the values:
        # bmc_username: <%= nil_to_null cluster_model.bmc_user %>
        # bmc_password: <%= nil_to_null cluster_model.bmc_password %>
        # gateway_ip: <%= nil_to_null cluster_model.gateway_ip %>

        # Sets the node to build when the mac address is set, edit with caution
        rebuild: <%= rebuild %>
        built: <%= built %>
      ERB

      EDIT_TEMPLATE = <<~ERB
        #{HEADER_COMMENT}

        # Trigger the node to rebuild next build:
        # > #{Config.app_name} build
        rebuild: <%= nil_to_null(rebuild?) %>

        # Flags the built state of the node
        built: <%= nil_to_null(built?) %>

        # Set the bmc username/ password and gateway ip
        bmc_username: <%= nil_to_null(bmc_user) %>
        bmc_password: <%= nil_to_null(bmc_password) %>
        gateway_ip: <%= nil_to_null(gateway_ip) %>

        # Set the groups the node is part of. The first group is always the
        # primary group
        groups:
        <% groups.each do |group| -%>
          - <%= group %>
        <% end -%>

        <%# DEV NOTE: A NilStruct is used when editing multiple nodes
            This works fine with the above properties as is renders to null,
            and thus skips being set unless changed. However, the properties
            below are unsettable in a bulk edit as they need to unique
        -%>
        <% if __getobj__.is_a? FlightMetal::Templator::NilStruct -%>
        # The addresses can not be set using a bulk edit
        # ip: IGNORED
        # fqdn: IGNORED
        # mac: IGNORED
        # bmc_ip: IGNORED
        <% else -%>
        # NOTE: The following can be unset with an empty string
        # Set the hardware address (mac) and the bmc ip address (bmc_ip)
        ip: <%= nil_to_null(ip) %>
        fqdn: <%= nil_to_null(fqdn) %>
        mac: <%= nil_to_null(mac) %>
        bmc_ip: <%= nil_to_null(bmc_ip) %>
        <% end -%>
      ERB

      command_require 'flight_metal/models/node',
                      'flight_metal/templator',
                      'flight_metal/system_command'

      include Concerns::NodeattrParser

      def create(name, fields: nil)
        builder = Models::Node::Builder.new(cluster: Config.cluster, name: name)
        new_data = if fields
          YAML.safe_load(fields, symbolize_names: true)
        else
          Templator.new(builder).edit_yaml(CREATE_TEMPLATE)
        end
        new_data.reject! do |key, value|
          builder[key] == value || value.nil?
        end
        builder.merge!(new_data).create
      end

      def edit(nodes_str, fields: nil)
        nodes = nodeattr_parser(nodes_str)
        nodes.raise_if_missing
        data = edit_data(nodes, fields)
        if nodes.length == 1
          trim = trim_data(nodes.first, data, SINGLE_EDITABLE)
          update(nodes.first, trim)
        else
          nodes.each do |node|
            trim = trim_data(node, data, MULTI_EDITABLE)
            update(node, trim)
          end
        end
      end

      def list
        nodes = Models::Node.glob_read(Config.cluster, '*')
                            .sort_by { |n| n.name }
        outputs = SystemCommand.new(*nodes).fqdn_and_ip
        sys_nodes = nodes.each_with_index
                         .map do |node, idx|
          SysIPDelegator.new(node, *outputs[idx].stdout.split)
        end
        md = sys_nodes.map { |n| Templator.new(n).markdown(LIST_TEMPLATE) }
                      .join
        puts md
      end

      def delete(name)
        Models::Node.delete!(Config.cluster, name)
      end

      private

      def edit_data(nodes, fields)
        return YAML.safe_load(fields, symbolize_names: true) if fields
        subject = (nodes.length == 1 ? nodes.first : nil)
        Templator.new(subject).edit_yaml(EDIT_TEMPLATE)
      end

      def trim_data(node, data, whitelist)
        data.reject do |key, value|
          next true unless whitelist.include?(key)
          next true if value.nil?
          next true if node.send(key) == value
        end
      end

      def update(node, data)
        return if data.empty?
        groups = data.delete(:groups)&.reject { |g| g.nil? || g.empty? }
        node_model = Models::Node.update(Config.cluster, node.name) do |n|
          data.each { |k, v| n.send("#{k}=", v) }
        end
        if groups && node_model.groups != groups
          Models::Nodeattr.create_or_update(Config.cluster) do |attr|
            attr.add_nodes(node.name, groups: groups)
          end
        end
      end
    end
  end
end
