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

require 'flight_metal/command'
require 'flight_metal/commands/build'
require 'flight_metal/commands/cluster'
require 'flight_metal/commands/dhcp'
require 'flight_metal/commands/import'
require 'flight_metal/commands/ipmi'
require 'flight_metal/commands/hunt'
require 'flight_metal/commands/node'

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

    def self.syntax(command, args_str = '', opts: true)
      command.syntax = <<~SYNTAX.squish
        #{program(:name)} #{command.name} #{args_str} #{'[options]' if opts}
      SYNTAX
    end

    command 'build' do |c|
      syntax(c)
      c.summary = 'Setup the pxelinux file for the build'
      action(c, FlightMetal::Commands::Build)
    end

    command 'create' do |c|
      syntax(c, 'NODE')
      c.summary = 'Add a new node to the cluster'
      c.description = <<~DESC
        Opens up the the NODE configuration in your system edittor. The
        `pxelinux_file` and `kickstart_file` fields are required and must
        specify the paths to the corresponding files.

        All other fields are optional on create, but maybe required for the
        advanced features to work. See the edittor notes for further details.

        To create a node in a non-interactive shell, use the --fields flag
        with JSON syntax.
      DESC
      action(c, FlightMetal::Commands::Node, method: :create)
    end

    command 'edit' do |c|
      syntax(c, 'NODE_RANGE')
      c.summary = 'Edit the properties of the node(s)'
      c.description = <<~DESC
        Edits the nodes given by NODE_RANGE. The range is expanded using
        standard nodeattr syntax. This command can be used to edit the
        built state and address information for a single or multiple nodes.

        By default the command will open the editable fields in your system
        edittor. Refer to this document for a full list of fields that can
        be edited.

        Alternatively, the update values can be given using json syntax with
        --fields flag. This bypasses the interactive editor and updates the
        fields directly.
      DESC
      c.option '--fields JSON', 'The updated fields to be saved'
      action(c, FlightMetal::Commands::Node, method: :edit)
    end

    command 'hunt' do |c|
      syntax(c)
      c.summary = 'Collect node mac addesses from DHCP Discover'
      action(c, FlightMetal::Commands::Hunt)
    end

    command 'import' do |c|
      syntax(c)
      c.summary = 'Add node configuration profiles'
      c.description = <<~DESC
        Add node configuration profiles from a flight-architect output zip.
      DESC
      action(c, FlightMetal::Commands::Import)
    end

    command 'ipmi' do |c|
      syntax(c, 'NODE [...] [options] [--] [ipmi-options]', opts: false)
      c.summary = 'Run commands with ipmitool'
      c.description = <<~DESC
        The ipmi command wraps the underlining ipmitool utility. Please
        refer to ipmitool man page for full list of subcommands or run:
        `#{Config.app_name} ipmi help`.

        This tool communicates using BMC over Ethernet and as such the
        following ipmitool options will be set:

        * The interface will always be set with: `-I lanplus`,
        * The remote server is set to: `-H <NODE>.bmc`
        * And the username/password will be resolved from the configs and
          set with: `-U <username>` and `-P <password>`

        Additional options can be passed to directly to `ipmitool` by placing
        them after the optional double hypen: `--`. Without the hypen, the
        flags will be interpreted by `#{Config.app_name}` and likely cause an
        eror.
      DESC
      action(c, FlightMetal::Commands::Ipmi)
    end

    command 'init-cluster' do |c|
      syntax(c, 'IDENTIFIER BMC_USERNAME BMC_PASSWORD')
      c.summary = 'Create a new cluster profile'
      c.description = <<~DESC
        Create and switch to the new cluster IDENTIFIER. The BMC_USERNAME and
        BMC_PASSWORD become the defaults for the entire cluster
      DESC
      action(c, FlightMetal::Commands::Cluster, method: :init)
    end

    command 'list' do |c|
      syntax(c)
      c.summary = 'Display the state of all the nodes'
      action(c, FlightMetal::Commands::Node, method: :list)
    end

    command 'list-clusters' do |c|
      syntax(c)
      c.summary = 'Display the list of clusters'
      action(c, FlightMetal::Commands::Cluster, method: :list)
    end

    command 'power' do |c|
      syntax(c, 'NODE COMMAND')
      c.summary = 'Manage and check the power status of the nodes'
      c.description = <<~DESC.chomp
        Runs a power related command using ipmitool. The valid commands
        are:

        #{
          cmds_hash = FlightMetal::Commands::Ipmi::POWER_COMMANDS
          max_len = cmds_hash.keys.max_by(&:length).length
          cmds_hash.reduce([]) do |s, (k, v)|
            s << "  * #{k}#{' ' * (max_len - k.length)} - #{v[:help]}"
          end.join("\n")
        }
      DESC
      action(c, FlightMetal::Commands::Ipmi, method: :power)
    end

    command 'update-dhcp' do |c|
      syntax(c)
      c.summary = 'Update the DHCP server with the nodes mac addresses'
      action(c, FlightMetal::Commands::DHCP, method: :update)
    end

    command 'switch-cluster' do |c|
      syntax(c, 'IDENTIFIER')
      c.summary = 'Change the current cluster profile'
      action(c, FlightMetal::Commands::Cluster, method: :switch)
    end
  end
end
