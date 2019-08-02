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
require 'flight_metal/commands/edit'
require 'flight_metal/commands/hunt'
require 'flight_metal/commands/import'
require 'flight_metal/commands/init'
require 'flight_metal/commands/ipmi'
require 'flight_metal/commands/node'
require 'flight_metal/commands/render'

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

    command 'create' do |c|
      syntax(c, 'NODE')
      c.summary = 'Add a new node to the cluster'
      TemplateMap.flag_hash.each do |_, flag|
        c.option "--#{flag} FILE", "Path to the '#{flag.gsub('-', ' ')}' file"
      end
      action(c, FlightMetal::Commands::Init, method: :node)
    end

    command 'delete' do |c|
      syntax(c, 'NODE')
      c.summary = 'Remove the node and associated configurations'
      action(c, FlightMetal::Commands::Node, method: :delete)
    end

    command 'edit' do |c|
      syntax(c, 'TYPE IDENTIFIER')
      c.summary = 'Edit the associated files'
      c.option '--touch', 'Create an empty file if it does not already exist'
      c.option '--replace FILE', 'Copy the given FILE content instead of editing'
      action(c, FlightMetal::Commands::Edit)
    end

    command 'update' do |c|
      syntax(c, 'NODE PARAMS...')
      c.summary = "Modify the node's parameters"
      c.description = <<~DESC
        Set, modify, and delete parameters assigned to the NODE. The parameter
        keys must be an alphanumeric string which may contain underscores.

        PARAMS can set or modify keys by using `key=value` notation. The key can
        be hard set to an empty string by omitting the value: `key=`. Keys are
        permanently deleted when suffixed with a exclamation: `key!`.
      DESC
      action(c, FlightMetal::Commands::Node, method: :update)
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

    command 'hunt' do |c|
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

    command 'list' do |c|
      syntax(c)
      c.summary = 'Display the state of all the nodes'
      c.description = <<~DESC
        Shows the current state, grouping and parameter's of a node.

        The parameters used to populate the templates during `render`. Use the `update`
        command to modify the parameters.
      DESC
      action(c, FlightMetal::Commands::Node, method: :list)
    end

    command 'list-clusters' do |c|
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

    command 'render' do |c|
      syntax(c, 'TYPE NODE')
      c.summary = 'Render the template against the node parameters'
      c.description = <<~DESC.chomp
        Render the domain or group template for a node. All occurrences of
        `%param%` will be replaced with the node's parameter values. By default,
        the command will error if a tag has not been replaced. This can be overridden
        using the --force flag.
      DESC
      c.option '--force', 'Allow missing tags when writing the file'
      action(c, FlightMetal::Commands::Render)
    end

    command 'switch-cluster' do |c|
      syntax(c, 'IDENTIFIER')
      c.summary = 'Change the current cluster profile'
      action(c, FlightMetal::Commands::Cluster, method: :switch)
    end
  end
end
