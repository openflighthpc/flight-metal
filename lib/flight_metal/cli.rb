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
# For more information on flight-metal, please visit:
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
require 'flight_metal/commands/create'
require 'flight_metal/commands/delete'
require 'flight_metal/commands/edit'
require 'flight_metal/commands/file_command'
require 'flight_metal/commands/group_nodes'
require 'flight_metal/commands/import'
require 'flight_metal/commands/ipmi'
require 'flight_metal/commands/list'
require 'flight_metal/commands/list_nodes'
require 'flight_metal/commands/miscellaneous'
require 'flight_metal/commands/template'
require 'flight_metal/commands/update'

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

    def self.syntax(command, args_str = '', hidden: true)
      command.syntax = <<~SYNTAX.squish
        #{program(:name)} #{command.name} #{args_str}
      SYNTAX
      command.hidden = hidden
    end

    def self.multilevel_cli_syntax(command, level, args_str)
      combined_args = if level == :cluster
                        args_str
                      else
                        "#{level.to_s.upcase} #{args_str}"
                      end
      command.syntax = <<~SYNTAX.squish
        #{program(:name)} #{command.name} #{combined_args}
      SYNTAX
      command.hidden = true
    end

    # TODO: Remove me when refactoring is done
    def self.xcommand(*_a); end

    ['cluster', 'group', 'node'].each do |level|
      # This is caught by Commander and triggers the help text to be displayed
      command level do |c|
        syntax(c, hidden: false)
        snippet = (level == 'node' ? 'a node resource' : "the #{level} resource")
        c.summary = "View, configure, or manage #{snippet}"
        c.sub_command_group = true
      end

      command "#{level} action" do |c|
        syntax(c)
        if level == 'node'
          c.summary = 'Execute an action on the node'
        else
          c.summary = "Execute an action on all the nodes within the #{level}"
        end
        c.sub_command_group = true
      end
    end

    ['cluster', 'group', 'node'].each do |level|
      command "#{level} action build" do |c|
        level == 'cluster' ? syntax(c) : syntax(c, level.upcase)
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
        case level
        when 'cluster'
          c.action(&Commands::Build.unnamed_commander_proxy(:cluster, method: :run))
        when 'group'
          c.option '--primary', 'Only build nodes within the primary group'
          c.action(&Commands::Build.named_commander_proxy(:group, method: :run))
        when 'node'
          c.action(&Commands::Build.named_commander_proxy(:node, method: :run))
        end
      end
    end

    command 'cluster switch' do |c|
      syntax(c, 'IDENTIFIER')
      c.summary = 'Change the current cluster profile'
      c.action(&Commands::Miscellaneous.named_commander_proxy(:cluster, method: :switch_cluster))
    end

    command 'node create' do |c|
      syntax(c, 'NODE MAC')
      c.summary = 'Add a new node to the cluster'
      c.action(&FlightMetal::Commands::Create.named_commander_proxy(:node))
    end

    command 'cluster create' do |c|
      syntax(c, 'IDENTIFIER')
      c.summary = 'Create a new cluster profile'
      c.action(&Commands::Create.named_commander_proxy(:cluster))
    end

    command 'node delete' do |c|
      syntax(c, 'NODE')
      c.summary = 'Remove the node and associated configurations'
      c.action(Commands::Delete.named_commander_proxy(:node))
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

    command 'cluster list' do |c|
      syntax(c)
      c.summary = "Display the list of clusters"
      c.action(&Commands::List.unnamed_commander_proxy(:cluster, index: :clusters))
    end

    command 'group list' do |c|
      syntax(c)
      c.summary = "Display the list of groups"
      c.action(&Commands::List.unnamed_commander_proxy(:cluster, index: :groups))
    end

    command 'group show' do |c|
      syntax(c, 'GROUP')
      c.summary = "Display a group's details"
      c.action(&Commands::Miscellaneous.named_commander_proxy(:group, method: :show_group))
    end

    command 'group nodes' do |c|
      syntax(c)
      c.summary = 'Manage the nodes within the group'
      c.sub_command_group = true
    end

    command 'group nodes list' do |c|
      syntax(c, 'GROUP')
      c.summary = 'List all the nodes within the group'
      c.option '--primary', 'Only list the nodes within the primary group'
      c.option '--verbose', 'Show greater details'
      c.action(&Commands::List.named_commander_proxy(:group, index: :nodes))
    end

    command 'group nodes add' do |c|
      syntax(c, 'GROUP NODES')
      c.summary = 'add nodes to the group'
      c.option '--primary', 'Set the nodes to belong within the primary group'
      c.action(&Commands::GroupNodes.named_commander_proxy(:group, method: :add))
    end

    command 'group nodes remove' do |c|
      syntax(c, 'GROUP NODES')
      c.summary = 'remove the nodes from the group'
      c.action(&Commands::GroupNodes.named_commander_proxy(:group, method: :remove))
    end

    command 'node update' do |c|
      syntax(c, 'NODE [PARAMS...]')
      c.summary = 'Set the other parameters associated with the node'
      c.description = <<~DESC.chomp
        Set, modify, and delete other parameters for the node. The parameter
        keys must be an alphanumeric string which may contain underscores. The rebuild
        tag and mac address can also be udpated using the optional flags.

        Setting the rebuild tag to false will permanently disable the build command
        for the node. Alternatively, setting it will trigger it to build next time
        an appropriate build command is called. Any build issues will still need to
        be resolved before a rebuild will occurr.

        The mac address is used internally and can not be updated as a parameter.
        Instead specifiy the new mac address using the '--mac' flag. This may result
        in the system pxelinux file being abandoned as it is mac address specific.
        Use with caution!

        Parameters can set or modify keys by using `key=value` notation. The key can
        be hard set to an empty string by omitting the value: `key=`. Keys are
        permanently deleted when suffixed with an exclamation: `key!`.
      DESC
      c.option '--rebuild [false]', 'Flag the node to be rebuild. Unset by including false'
      c.option '--mac ADDRESS', 'Specify an updated hardware address for the node'
      c.action(&Commands::Update.named_commander_proxy(:node))
    end

    command 'node show' do |c|
      syntax(c, 'NODE')
      c.summary = 'View the details about the node'
      c.action(&Commands::ListNodes.named_commander_proxy(:node, method: :shared_verbose))
    end

    command 'node list' do |c|
      syntax(c)
      c.summary = 'Display all the nodes in the cluster'
      c.action(&Commands::List.unnamed_commander_proxy(:cluster, index: :nodes))
    end

    command 'node edit' do |c|
      syntax(c, 'NODE')
      c.summary = "Modify the node's other parameters via the editor"
      c.action(&Commands::Update.named_commander_proxy(:node, method: :node_editor))
    end

    def self.plugin_command(name)
      method = name.gsub('-', '_').to_sym
      ['cluster', 'group', 'node'].each do |level|
        command "#{level} action #{name}" do |c|
          syntax(c, "#{level.upcase + ' ' unless level == 'cluster'}[SHELL_ARGS...]")
          c.summary = "Run the #{c.name} script"
          case level
          when 'cluster'
            c.action(&Commands::Ipmi.unnamed_commander_proxy(:cluster, method: method))
          when 'group'
            c.option '--primary', 'Only run the command for nodes within the primary group'
            c.action(&Commands::Ipmi.named_commander_proxy(:group, method: method))
          when 'node'
            c.action(&Commands::Ipmi.named_commander_proxy(:node, method: method))
          end
        end
      end
    end

    ['power-on', 'power-off', 'power-status', 'ipmi'].each { |c| plugin_command(c) }

    command 'cluster node-template' do |c|
      syntax(c)
      c.summary = 'Manage the cluster wide default node templates'
      c.sub_command_group = true
    end

    command 'node template' do |c|
      syntax(c)
      c.summary = 'View and manage the source template'
      c.sub_command_group = true
    end

    command "node file" do |c|
      syntax(c)
      c.summary = 'View and update the content files for the node'
      c.sub_command_group = true
    end

    [:cluster, :node].each do |level|
      cli_prefix = (level == :node ? 'node template' : 'cluster node-template')

      [:add, :remove, :touch, :show, :edit, :render].each do |cmd|
        command "#{cli_prefix} #{cmd}" do |c|
          if cmd == :add
            multilevel_cli_syntax(c, level, 'TYPE TEMPLATE_PATH')
          elsif cmd == :render && level == :cluster
            multilevel_cli_syntax(c, level, 'NODE TYPE')
          else
            multilevel_cli_syntax(c, level, 'TYPE')
          end

          case cmd
          when :add
            c.summary = 'Define a new template from the file system'
          when :remove
            if level == :node
              c.summary = 'Delete the node level template'
            else
              c.summary = 'Delete the cluster wide node default template'
            end
          when :touch
            c.summary = 'Create an empty template ready to be edited'
          when :show
            if level == :node
              c.summary = 'View the node level template'
            else
              c.summary = 'View the cluster wide node default template'
            end
          when :edit
            c.summary = 'Update the template through the system editor'
          when :render
            c.summary = 'Render the template to stdout'
          end

          method = (cmd == :render && level == :cluster ? :render_node : cmd)

          if level == :cluster
            c.action(&Commands::Template.unnamed_commander_proxy(:cluster, method: method, index: :nodes))
          else
            c.action(&Commands::Template.named_commander_proxy(level, method: method))
          end
        end
      end
    end

    [:add, :remove, :touch, :show, :edit, :source, :render, :update].each do |cmd|
      command "node file #{cmd}" do |c|
        if cmd == :add
          syntax(c, "NODE TYPE TEMPLATE_PATH")
        else
          syntax(c, "NODE TYPE")
        end

        case cmd
        when :add
          c.summary = 'Add a file directly from the file system'
        when :remove
          c.summary = 'Permanently delete a file'
        when :touch
          c.summary = 'Create an empty file read for editing'
        when :show
          c.summary = 'Print the file to stdout'
        when :edit
          c.summary = 'Update the file via the system editor'
        when :source
          c.summary = 'Display template source information for the file'
        when :render
          c.summary = 'Render the source template against the node to stdout'
        when :update
          c.summary = 'Render the source template against the node and save the result'
        end
        c.action(&Commands::FileCommand.named_commander_proxy(:machine, method: cmd))
      end
    end
  end
end
