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
require 'flight_metal/commands/create'
require 'flight_metal/commands/edit'
require 'flight_metal/commands/hunt'
require 'flight_metal/commands/import'
require 'flight_metal/commands/ipmi'
require 'flight_metal/commands/list_nodes'
require 'flight_metal/commands/miscellaneous'
require 'flight_metal/commands/node'
require 'flight_metal/commands/update'
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
        Links the kickstart, pxelinux, and dhcp files into places before starting
        the build server. The build server listens for UDP packets on port
        #{Config.build_port}.

        The node must have a MAC address and the above files must be pending/installed.
        Built nodes are flagged to prevent them from rebuilding. To force a rebuild,
        please use the `#{Config.app_name} update` with the --rebuild flag.

        The files are symlinked into place, which transitions them from the pending
        to installed state. If the there is a file conflict, then the node will be
        skipped. Conflicts files are listed as invalid in `#{Config.app_name} list`.

        The build server listens for JSON messages that specifies the `node` name
        and `built` flag. The kickstart and pxelinux file are removed at the end of
        the build, where the dhcp file will remain.

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

    command 'node-create' do |c|
      syntax(c, 'NODE')
      c.summary = 'Add a new node to the cluster'
      c.action(&FlightMetal::Commands::Create.named_commander_proxy(:node))
    end

    command 'cluster-create' do |c|
      syntax(c, 'IDENTIFIER')
      c.summary = 'Create a new cluster profile'
      c.action(&Commands::Create.named_commander_proxy(:cluster))
    end

    xcommand 'delete' do |c|
      syntax(c, 'NODE')
      c.summary = 'Remove the node and associated configurations'
      action(c, FlightMetal::Commands::Node, method: :delete)
    end

    xcommand 'edit' do |c|
      syntax(c, 'domain|[NODE|GROUP] TYPE')
      c.summary = 'Edit a domain/group template or node file'
      c.description = <<~DESC.chomp
        Open a template/script/build file in the editor. This is used to manage
        the build process and power commands. Specify which file is to be edited
        with TYPE field. The supported types are listed below.

        The command works in three distinct modes based on the target:
        - domain
          Edits the default template used by the `render` command. Activated when
          called with the 'domain' keyword

        - NODE
          Edit the rendered file used by a particular node. Defaults to this mode
          when called with a name

        - --group GROUP
          Edit the group level template to be used when rendering a node. See the
          `render` for further details. Activated when called with the --group
          option. Can not be used in combination with domain.

        Valid TYPE arguments:
          - #{TemplateMap.flag_hash.values.join("\n  - ")}
      DESC
      c.option '-g', '--group', 'Switch the input from NODE to GROUP mode'
      c.option '--touch', 'Create an empty file if it does not already exist'
      c.option '--replace FILE', 'Copy the given FILE content instead of editing'
      action(c, FlightMetal::Commands::Edit)
    end

    command 'node-update' do |c|
      syntax(c, 'NODE [PARAMS...]')
      c.summary = "Modify the node's parameters"
      c.description = <<~DESC
        Set, modify, and delete parameters assigned to the NODE. The parameter
        keys must be an alphanumeric string which may contain underscores.

        PARAMS can set or modify keys by using `key=value` notation. The key can
        be hard set to an empty string by omitting the value: `key=`. Keys are
        permanently deleted when suffixed with a exclamation: `key!`.
      DESC
      c.option '--rebuild [false]',
               "Flag the node to be rebuilt. Unset by including 'false'"
      c.action(&Commands::Update.named_commander_proxy(:node))
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

    command 'cluster-list' do |c|
      syntax(c)
      c.summary = 'Display the list of clusters'
      c.action(&Commands::Miscellaneous.unnamed_commander_proxy(:cluster, method: :list_clusters))
    end

    shared_cluster_list_nodes = ->(c) do
      syntax(c)
      c.summary = 'List all the nodes within the cluster'
      c.option '--verbose', 'Show greater details'
      c.action(&Commands::ListNodes.unnamed_commander_proxy(:cluster, method: :shared))
    end

    command 'node-list' do |c|
      shared_cluster_list_nodes.call(c)
    end

    command 'group-list-nodes' do |c|
      syntax(c, 'GROUP')
      c.summary = 'List thes nodes within the group'
      c.option '--verbose', 'Show greater details'
      c.option '--primary', 'Only show primary nodes'
      c.action do |args, opts|
        proxy = if opts.__hash__.delete(:primary)
          Commands::ListNodes.named_commander_proxy(:primary_group, method: :shared)
        else
          Commands::ListNodes.named_commander_proxy(:group, method: :shared)
        end
        proxy.call(args, opts)
      end
    end

    command 'cluster-list-nodes' do |c|
      shared_cluster_list_nodes.call(c)
    end

    def self.plugin_command(name)
      xcommand name do |c|
        syntax(c, 'NODE, [SHELL_ARGS...]')
        c.summary = "Run the #{c.name} script"
        c.option '-n', '--nodes-in', 'Switch the input to the nodes within the GROUP'
        c.option '-p', '--primary-nodes-in',
                 'Switch the input to nodes belonging to the primary group'
        action(c, FlightMetal::Commands::Ipmi, method: c.name.gsub('-', '_'))
      end
    end

    ['power-on', 'power-off', 'power-status', 'ipmi'].each { |c| plugin_command(c) }

    xcommand 'render' do |c|
      syntax(c, '[NODE|GROUP] TYPE')
      c.summary = 'Render the template against the node parameters'
      c.description = <<~DESC.chomp
        Generate content files for a node based off a template. The valid TYPE
        arguments are given below. The templates are rendered against the
        node's paramters. The subtitution delimited by pairs of '%' around
        the key (e.g. 'my %key%' would render to: 'my value').

        The command works in the following modes:
        - NODE
          By default, render a template for a single node. The node's primary
          group template is used preferentially with the domain template as a
          fallback.

        - --nodes-in GROUP
          Renders the template(s) for all nodes within the GROUP
          Note: The template selection is based on primary group only. This may
          use multiple templates

        - --primary-nodes-in GROUP
          Renders the template for nodes who have GROUP as their primary.
      DESC
      c.option '--force', 'Allow missing tags when writing the file'
      c.option '-n', '--nodes-in', 'Switch the input to the nodes within the GROUP'
      c.option '-p', '--primary-nodes-in',
               'Switch the input to nodes belonging to the primary group'
      action(c, FlightMetal::Commands::Render)
    end

    command 'cluster-switch' do |c|
      syntax(c, 'IDENTIFIER')
      c.summary = 'Change the current cluster profile'
      c.action(&Commands::Miscellaneous.named_commander_proxy(:cluster, method: :switch_cluster))
    end
  end
end
