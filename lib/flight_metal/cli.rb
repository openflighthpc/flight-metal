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

require 'commander'
require 'flight_metal/config'
require 'flight_metal/log'
require 'flight_metal/version'

require 'active_support/core_ext/string'

require 'flight_metal/template_map'
require 'flight_metal/command'
require 'flight_metal/commands/build'
require 'flight_metal/commands/cluster'
require 'flight_metal/commands/dhcp'
require 'flight_metal/commands/import'
require 'flight_metal/commands/init'
require 'flight_metal/commands/ipmi'
require 'flight_metal/commands/hunt'
require 'flight_metal/commands/node'

require 'pry' if FlightMetal::Config.debug

module FlightMetal
  class CLI
    extend Commander::UI
    extend Commander::UI::AskForClass
    extend Commander::Delegates

    program :name, Config.app_name
    program :version, FlightMetal::VERSION
    program :description, 'Deploy bare metal machines'
    program :help_paging, false

    def self.run!
      ARGV.push '--help' if ARGV.empty?
      Log.info "Command: #{Config.app_name} #{ARGV.join(' ')}"
      super
    end

    def self.action(command, klass, method: :run)
      command.action do |args, opts|
        hash = opts.__hash__
        hash.delete(:trace)
        begin
          if hash.empty?
            klass.new.public_send(method, *args)
          else
            klass.new.public_send(method, *args, **hash)
          end
        rescue Interrupt
          Log.warn_puts 'Received Interrupt!'
        rescue => e
          Log.fatal(e)
          raise e
        end
      end
    end

    def self.syntax(command, args_str = '')
      command.syntax = <<~SYNTAX.squish
        #{program(:name)} #{command.name} #{args_str}
      SYNTAX
    end

    # TODO: Remove me when refactoring is done
    def self.xcommand(*_a); end

    xcommand 'build' do |c|
      syntax(c)
      c.summary = 'Run the pxelinux build server'
      c.description = <<~DESC
        Moves the kickstart file and pxelinux files into places before starting
        the build server. The build server listens for UDP packets on port #{Config.build_port}.

        Only nodes with a MAC address, pxelinux and kickstart files will be built
        There is no need to specify which nodes need to be built. Built nodes are
        flagged internally and will not appear in the build process again. To force
        a rebuild, please use the `#{Config.app_name} edit` command and set the `rebuild`
        flag to true.

        This command will write the kickstart and pxelinux files into the system
        location when the build commences. Existing files are not overridden by build
        as they could be in use; instead a warning will be issued.

        The build server listens for JSON messages that specifies the `node` name
        and `built` flag. This triggers the build files to be removed from their
        system location and the server stops listening for the node.

        It is possible to send status updates to the server by specifing the `node`
        name and `message` in the JSON. The `message` will be printed to the display
        for inspection. Nodes can not send status messages once they have finished
        building.

        The command will end once all the nodes have reported back. Using interrupt
        with build is not recommended as it can cause built messages to be skipped.
        However as the build files are not removed on interrupt, the process can be
        recommenced by calling build again.
      DESC
      action(c, FlightMetal::Commands::Build)
    end

    xcommand 'create' do |c|
      syntax(c, 'NODE')
      c.summary = 'Add a new node to the cluster'
      c.description = <<~DESC
        Opens up the NODE configuration in your system editor. The
        `pxelinux_file` and `kickstart_file` fields are required and must
        specify the paths to the corresponding files.

        All other fields are optional on create, but maybe required for the
        advanced features to work. See the editor notes for further details.

        To create a node in a non-interactive shell, use the --fields flag
        with JSON syntax.
      DESC
      c.option '--fields JSON', 'The fields to be saved'
      action(c, FlightMetal::Commands::Node, method: :create)
    end

    xcommand 'delete' do |c|
      syntax(c, 'NODE')
      c.summary = 'Remove the node and associated configurations'
      action(c, FlightMetal::Commands::Node, method: :delete)
    end

    xcommand 'edit' do |c|
      syntax(c, 'NODE_IDENTIFIER')
      c.summary = 'Edit the properties of the node(s)'
      c.description = <<~DESC
        Edits the nodes given by NODE_IDENTIFIER. The identifier is expanded
        using standard nodeattr syntax. This command can be used to edit the
        built state and address information for a single or multiple nodes.
        Alternatively, the NODE_IDENTIFIER can be used to specify a group of
        nodes when used with the --group flag.

        By default the command will open the editable fields in your system
        editor. Refer to this document for a full list of fields that can
        be edited.

        Alternatively, the update values can be given using json syntax with
        --fields flag. This bypasses the interactive editor and updates the
        fields directly.
      DESC
      c.option '--fields JSON', 'The updated fields to be saved'
      c.option '-g', '--group', 'Run the command over the nodes given by NODE_IDENTIFIER'
      action(c, FlightMetal::Commands::Node, method: :edit)
    end

    xcommand 'edit-cluster' do |c|
      syntax(c)
      c.summary = 'Update the current cluster configuration'
      c.description = <<~DESC
        Opens the current cluster configuration in and editor to be updated.
        See the editor comments for a description of the edittable fields.

        The editor can be bypassed by using the --fields flag instead.
      DESC
      c.option '--fields JSON', 'The updated fields to be saved'
      action(c, FlightMetal::Commands::Cluster, method: :edit)
    end

    xcommand 'hunt' do |c|
      syntax(c)
      c.summary = 'Collect node mac addesses from DHCP Discover'
      c.description = <<~DESC
        Listens for DHCP DISCOVER packets containing PXEClient as its vendor
        class ID. The MAC address will be extracted from the discover and can
        be assigned to a node.
      DESC
      action(c, FlightMetal::Commands::Hunt)
    end

    xcommand 'import' do |c|
      syntax(c, 'MANIFEST_PATH')
      c.summary = 'Add node configuration profiles'
      c.description = <<~DESC
        Add node configuration profiles from a Flight manifest. The MANIFEST_PATH
        should give the directory the "manifest.yaml" lives in or the file itself.
        The --force flag can be used to update the cluster configuration and
        existing nodes.

        The --init flag will create and switch to a new cluster before
        preforming a full import. By default the command will error if the
        cluster already exists. However the exists check will be ignored
        if used with the --force flag.
      DESC
      c.option '-i', '--init CLUSTER', String,
               'Create and import into a new CLUSTER'
      c.option '-f', '--force', 'Force replace existing configuration'
      action(c, FlightMetal::Commands::Import)
    end

    xcommand 'ipmi' do |c|
      syntax(c, 'NODE_IDENTIFIER [...] [--] [ipmi-options]')
      c.summary = 'Run commands with ipmitool'
      c.description = <<~DESC
        The ipmi command wraps the underlining ipmitool utility. Please
        refer to commands list below or ipmitool man page for full details.

        This tool communicates using BMC over Ethernet and as such the
        following ipmitool options will be set:

        * The interface will always be set with: `-I lanplus`,
        * The remote server is set to: `-H <NODE_IDENTIFIER>.bmc`
        * And the username/password will be resolved from the configs and
          set with: `-U <username>` and `-P <password>`

        Additional options can be passed to directly to `ipmitool` by placing
        them after the optional double hypen: `--`. Without the hypen, the
        flags will be interpreted by `#{Config.app_name}` and likely cause an
        eror.

        The ipmi command can be ran over multiple nodes by specifying a range
        as part of the NODE_IDENTIFIER (e.g. node[01-10] for node01 to node10).
        Alternatively the --group flag toggle the command to ran over all the
        nodes within the group specified by NODE_IDENTIFIER.

        IPMI Commands:
        #{Config.ipmi_commands_help}
      DESC
      c.option '-g', '--group', 'Run the command over the nodes given by NODE_IDENTIFIER'
      action(c, FlightMetal::Commands::Ipmi)
    end

    command 'init-cluster' do |c|
      syntax(c, 'IDENTIFIER')
      c.summary = 'Create a new cluster profile'
      c.option '--fields JSON', 'The cluster fields to be saved'
      TemplateMap.flag_hash.each do |_, flag|
        c.option "--#{flag} TEMPLATE", "Path to the '#{flag.gsub('-', ' ')}' template"
      end
      action(c, FlightMetal::Commands::Init)
    end

    xcommand 'list' do |c|
      syntax(c)
      c.summary = 'Display the state of all the nodes'
      action(c, FlightMetal::Commands::Node, method: :list)
    end

    xcommand 'list-clusters' do |c|
      syntax(c)
      c.summary = 'Display the list of clusters'
      action(c, FlightMetal::Commands::Cluster, method: :list)
    end

    xcommand 'power' do |c|
      syntax(c, 'NODE_IDENTIFIER COMMAND')
      c.summary = 'Manage and check the power status of the nodes'
      c.description = <<~DESC.chomp
        Runs a power related command using ipmitool. The valid commands
        are given below. Similarly to the ipmi command, the NODE_IDENTIFIER
        can specify a:
        1. Single node,
        2. A range of nodes (e.g. node[01-10] for node01 to node10), or
        3. A group of nodes when used with the --group flag

        Power Commands:
        #{
          cmds_hash = FlightMetal::Commands::Ipmi::POWER_COMMANDS
          max_len = cmds_hash.keys.max_by(&:length).length
          cmds_hash.reduce([]) do |s, (k, v)|
            s << "  * #{k}#{' ' * (max_len - k.length)} - #{v[:help]}"
          end.join("\n")
        }
      DESC
      c.option '-g','--group', 'Run the command over the nodes given by NODE_IDENTIFIER'
      action(c, FlightMetal::Commands::Ipmi, method: :power)
    end

    xcommand 'update-dhcp' do |c|
      syntax(c)
      c.summary = 'Update the DHCP server with the nodes mac addresses'
      c.description = <<~DESC.chomp
        Renders a partial DHCP configuration file with the nodes that have
        static ips and MAC addresses. The configuration is rendered to the
        dedicated file: #{Config.dhcpd_path}

        This file will not be automatically included by the main dhcpd.conf.
        Please confirm it has been updated if the nodes are being skipped.

        The dhcpd server will be automatically restarted once the config file
        has been updated.
      DESC
      action(c, FlightMetal::Commands::DHCP, method: :update)
    end

    xcommand 'switch-cluster' do |c|
      syntax(c, 'IDENTIFIER')
      c.summary = 'Change the current cluster profile'
      action(c, FlightMetal::Commands::Cluster, method: :switch)
    end
  end
end
