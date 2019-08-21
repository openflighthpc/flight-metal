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
require 'flight_metal/commands/delete'
require 'flight_metal/commands/edit'
require 'flight_metal/commands/hunt'
require 'flight_metal/commands/import'
require 'flight_metal/commands/ipmi'
require 'flight_metal/commands/list_nodes'
require 'flight_metal/commands/miscellaneous'
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

    def self.syntax(command, args_str = '', hidden: true)
      command.syntax = <<~SYNTAX.squish
        #{program(:name)} #{command.name} #{args_str}
      SYNTAX
      command.hidden = hidden
    end

    # TODO: Remove me when refactoring is done
    def self.xcommand(*_a); end


    ['cluster', 'group', 'node'].each do |level|
      command level do |c|
        syntax(c, hidden: false)
        snippet = (level == 'node' ? 'a node resource' : "the #{level} resource")
        c.summary = "View, configure, or manage #{snippet}"
        c.sub_command_group = true
        c.action do
          # This is caught by Commander and triggers the help text to be displayed
          raise Commander::Patches::CommandUsageError, <<~ERROR.chomp
            Select from the following commands:
          ERROR
        end
      end
    end

    ['cluster', 'group', 'node'].each do |level|
      command "#{level} build" do |c|
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
      syntax(c, 'NODE')
      c.summary = 'Add a new node to the cluster'
      c.action(&FlightMetal::Commands::Create.named_commander_proxy(:node))
    end

    command 'group create' do |c|
      syntax(c, 'GROUP')
      c.summary = 'Add a new group to the cluster'
      c.action(&FlightMetal::Commands::Create.named_commander_proxy(:group))
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

    ['cluster', 'node', 'group'].each do |level|
      command "#{level} edit" do |c|
        syntax(c, "#{level.upcase + ' ' unless level == 'cluster'}TYPE")
        c.summary = 'Open a managed node file in the editor'
        c.description = <<~DESC.chomp
          Open a template/script/build file in the editor. This is used to manage
          the build process and power commands. Specify which file is to be edited
          with TYPE field. The supported types are listed below.

          Valid TYPE arguments:
            - #{TemplateMap.flag_hash.values.join("\n  - ")}
        DESC
        c.option '--replace FILE', 'Copy the given FILE content instead of editing'
        if level == 'cluster'
          c.action(&Commands::Edit.unnamed_commander_proxy(:cluster, method: :run))
        else
          c.action(&Commands::Edit.named_commander_proxy(level.to_sym, method: :run))
        end
      end
    end

    ['node', 'group'].each do |level|
      command "#{level} update" do |c|
        syntax(c, "#{level.upcase} [PARAMS...]")
        c.summary = "Modify the #{level}'s parameters"
        c.description = <<~DESC
          Set, modify, and delete parameters assigned to the #{level.upcase}. The parameter
          keys must be an alphanumeric string which may contain underscores.

          PARAMS can set or modify keys by using `key=value` notation. The key can
          be hard set to an empty string by omitting the value: `key=`. Keys are
          permanently deleted when suffixed with a exclamation: `key!`.
        DESC
        case level
        when 'node'
          c.option '--rebuild [false]',
                   "Flag the node to be rebuilt. Unset by including 'false'"
          c.action(&Commands::Update.named_commander_proxy(:node))
        when 'group'
          c.action(&Commands::Update.named_commander_proxy(:group))
        end
      end
    end

    command 'hunt' do |c|
      syntax(c, hidden: false)
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

    command 'cluster list' do |c|
      syntax(c)
      c.summary = "Display the list of clusters"
      c.action(&Commands::Miscellaneous.unnamed_commander_proxy(:cluster, method: :list_clusters))
    end

    command 'group list' do |c|
      syntax(c)
      c.summary = "Display the list of groups"
      c.action(&Commands::Miscellaneous.unnamed_commander_proxy(:cluster, method: :list_groups))
    end

    command 'group show' do |c|
      syntax(c, 'GROUP')
      c.summary = "Display a group's details"
      c.action(&Commands::Miscellaneous.named_commander_proxy(:group, method: :list_groups))
    end

    ['cluster', 'group', 'node list', 'node show'].each do |level|
      name = case level
             when 'cluster'; 'cluster list-nodes'
             when 'group'; 'group list-nodes'
             else; level
             end
      command name do |c|
        c.option '--verbose', 'Show greater details'
        case level
        when 'cluster', 'node list'
          syntax(c)
          c.summary = 'List all the nodes within the cluster'
          c.action(&Commands::ListNodes.unnamed_commander_proxy(:cluster, method: :shared))
        when 'group'
          syntax(c, 'GROUP')
          c.summary = 'List all the nodes within the group'
          c.option '--primary', 'Only list nodes within the primary group'
          c.action(&Commands::ListNodes.named_commander_proxy(:group, method: :shared))
        when 'node show'
          syntax(c, 'NODE')
          c.summary = 'View the node state and configuration'
          c.action(&Commands::ListNodes.named_commander_proxy(:node, method: :shared))
        end
      end
    end

    def self.plugin_command(name)
      method = name.gsub('-', '_').to_sym
      ['cluster', 'group', 'node'].each do |level|
        command "#{level} #{name}" do |c|
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

    # Define the nodes rendering commands
    ['cluster', 'group', 'node'].each do |level|
      command "#{level} render#{ '-nodes' unless level == 'node'}" do |c|
        syntax(c, "#{level.upcase + ' ' unless level == 'cluster'}TYPE")
        c.summary = 'Render the template against the node parameters'
        c.option '--force', 'Allow missing tags when writing the file'
        case level
        when 'cluster'
          c.action(&Commands::Render.unnamed_commander_proxy(:cluster, index: :nodes))
        when 'group'
          # NOTE: Using --primary mutates :group to :primary_group within the proxy
          c.option '--primary', 'Only render nodes within the primary group'
         c.action(&Commands::Render.named_commander_proxy(:group, index: :nodes))
        when 'node'
          c.action(&Commands::Render.named_commander_proxy(:node, index: :nodes))
        end
      end
    end

    # Define the groups rendering commands
    ['cluster', 'group'].each do |level|
      command "#{level} render#{ '-groups' unless level == 'group' }" do |c|
        syntax(c, "#{ level.upcase + ' ' unless level == 'cluster' }TYPE")
        c.summary = 'Render the template against the group parameters'
        case level
        when 'cluster'
          c.action(&Commands::Render.unnamed_commander_proxy(:cluster, index: :groups))
        when 'group'
          c.action(&Commands::Render.named_commander_proxy(:group, index: :groups))
        end
      end
    end
  end
end
