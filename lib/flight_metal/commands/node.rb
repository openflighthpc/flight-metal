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
      LIST_TEMPLATE = <<~ERB
        # Node: '<%= name %>'
        *Imported*: <%= imported? ? imported_time : 'n/a' %>
        *Hunted*: <%= mac? ? mac_time : 'n/a' %>
        <% if built? -%>
        *Built*: <%= built_time %>
        *Rebuild*: <%= rebuild? ? 'Scheduled': 'n/a' %>
        <% else  -%>
        *Build*: <%= rebuild? ? 'Scheduled' : 'Skipping' %>
        <% end -%>

        *IP*: <%= catch_error { ip } %>
        *Domain Name*: <%= catch_error { fqdn } %>

        <% if mac? %>*MAC*: <%= mac %><% end %>
        <% if bmc_username %>*BMC Username*: <%= bmc_username %><% end %>
        <% if bmc_password %>*BMC Password*: <%= bmc_password %><% end %>
        <% if bmc_ip %>*BMC IP*: <%= bmc_ip %><% end %>
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

      MULTI_EDITABLE = [:rebuild, :built, :bmc_username, :bmc_password, :gateway_ip]
      SINGLE_EDITABLE = [*MULTI_EDITABLE, :mac, :bmc_ip, :ip, :fqdn]

      CREATE_TEMPLATE = <<~ERB
        #{HEADER_COMMENT}

        # Give the paths to the pxelinux and kickstart files. These files are
        # required for the build and must be given on create. The files will
        # be internally cached, so future changes to the source files will not
        # affect the build
        pxelinux_file:
        kickstart_file:

        # Set the primary network ip and fully qualified domain name. The
        # pre-set values (if present) have been retrieved using `gethostip`.
        # Only the cached values will be used to render the DHCP config
        <%
          output = FlightMetal::SystemCommand.new(self).fqdn_and_ip.first
          sys_fqdn , sys_ip = if output.exit_0?
                                output.stdout.split
                              else
                                ['null', 'null']
                              end
        -%>
        ip: <%= sys_ip %>
        fqdn: <%= sys_fqdn %>

        # Set the management ip address to preform ipmi/power commands
        bmc_ip: null

        # The hardware address can optional be set now or with the 'hunt'
        # command later
        # mac: null

        # Override the default bmc username/ password.
        # Uncomment the fields to hard set the values:
        # bmc_username: <%= nil_to_null links.cluster.bmc_user %>
        # bmc_password: <%= nil_to_null links.cluster.bmc_password %>

        # Sets the node to build when the mac address is set, edit with caution
        rebuild: true
        built: false
      ERB

      EDIT_TEMPLATE = <<~ERB
        #{HEADER_COMMENT}

        # Trigger the node to rebuild next build:
        # > #{Config.app_name} build
        rebuild: <%= nil_to_null(rebuild?) %>

        # Flags the built state of the node
        built: <%= nil_to_null(built?) %>

        # Set the bmc username and password
        bmc_username: <%= nil_to_null(bmc_user) %>
        bmc_password: <%= nil_to_null(bmc_password) %>

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
        Models::Node.create(Config.cluster, name) do |node|
          data = create_data(node, fields)
          pxelinux = data.delete(:pxelinux_file).to_s
          kickstart = data.delete(:kickstart_file).to_s
          if File.exists?(pxelinux) && File.exists?(kickstart)
            trim_data(node, data, SINGLE_EDITABLE).each do |k, v|
              node.send("#{k}=", v)
            end
            FileUtils.mkdir_p File.dirname(node.pxelinux_template_path)
            FileUtils.cp pxelinux, node.pxelinux_template_path
            FileUtils.mkdir_p File.dirname(node.kickstart_template_path)
            FileUtils.cp kickstart, node.kickstart_template_path
          elsif File.exists?(pxelinux)
            raise InvalidInput, <<~ERROR.squish
              The `kickstart_file` input is either missing or the file doesn't
              exist: #{kickstart}
            ERROR
          else
            raise InvalidInput, <<~ERROR.squish
              The `pxelinux_file` input is either missing or the file doesn't
              exist: #{pxelinux}
            ERROR
          end
        end
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
        md = Registry.new
                     .glob_read(Models::Node, Config.cluster, '*')
                     .sort_by { |n| n.name }
                     .map { |n| Templator.new(n).markdown(LIST_TEMPLATE) }
                     .join
        puts md
      end

      private

      def edit_data(nodes, fields)
        return YAML.safe_load(fields, symbolize_names: true) if fields
        subject = (nodes.length == 1 ? nodes.first : nil)
        Templator.new(subject).edit_yaml(EDIT_TEMPLATE)
      end

      def create_data(node, fields)
        templator = Templator.new(node)
        if fields
          templator.yaml(CREATE_TEMPLATE)
                   .merge(YAML.safe_load(fields, symbolize_names: true))
        else
          templator.edit_yaml(CREATE_TEMPLATE)
        end
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
        Models::Node.update(Config.cluster, node.name) do |n|
          data.each { |k, v| n.send("#{k}=", v) }
        end
      end
    end
  end
end
