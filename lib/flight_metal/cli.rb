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
require 'flight_metal/version'

require 'active_support/core_ext/string'

require 'flight_metal/commands/build'
require 'flight_metal/commands/cluster'
require 'flight_metal/commands/import'
require 'flight_metal/commands/hunter'

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
          $stderr.puts 'Received Interrupt!'
        end
      end
    end

    def self.syntax(command, args_str = '')
      command.syntax = <<~SYNTAX.squish
        #{program(:name)} #{command.name} #{args_str} [options]
      SYNTAX
    end

    command 'build' do |c|
      syntax(c)
      c.summary = 'Setup the pxelinux file for the build'
      action(c, FlightMetal::Commands::Build)
    end

    command 'hunter' do |c|
      syntax(c)
      c.summary = 'Collect node mac addesses from DHCP Discover'
      action(c, FlightMetal::Commands::Hunter)
    end

    command 'import' do |c|
      syntax(c)
      c.summary = 'Add node configuration profiles'
      c.description = <<~DESC
        Add node configuration profiles from a flight-architect output zip.
      DESC
      action(c, FlightMetal::Commands::Import)
    end

    command 'init-cluster' do |c|
      syntax(c, 'IDENTIFIER')
      c.summary = 'Create a new cluster profile'
      action(c, FlightMetal::Commands::Cluster, method: :init)
    end

    command 'list-clusters' do |c|
      syntax(c)
      c.summary = 'Display the list of clusters'
      action(c, FlightMetal::Commands::Cluster, method: :list)
    end

    command 'switch-cluster' do |c|
      syntax(c, 'IDENTIFIER')
      c.summary = 'Change the current cluster profile'
      action(c, FlightMetal::Commands::Cluster, method: :switch)
    end
  end
end
