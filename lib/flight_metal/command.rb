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

module FlightMetal
  module CommandHelper
    module ClassMethods
      def command_require(*a)
        command_requires.push(*a)
      end

      def command_requires
        @command_requires ||= []
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def initialize(*_a)
      self.class.command_requires.each { |d| require d }
      super if defined?(super)
    end
  end

  ScopedCommand = Struct.new(:level, :model_name, :index) do
    class CommanderProxy
      def self.named(klass, cli_level, name_and_args, commander_opts, index)
        name = name_and_args.first
        args = name_and_args[1..-1]
        level, opts_hash = resolve_level_and_hash(cli_level, commander_opts)
        cmd_instance = klass.new(level, name, index)
        new(cmd_instance, *args, **opts_hash)
      end

      def self.unnamed(klass, cli_level, args, commander_opts, index)
        level, opts_hash = resolve_level_and_hash(cli_level, commander_opts)
        cmd_instance = klass.new(level, nil, index)
        new(cmd_instance, *args, **opts_hash)
      end

      private_class_method

      def self.resolve_level_and_hash(cli_level, commander_opts)
        hash = commander_opts.__hash__.dup.tap { |h| h.delete(:trace) }
        if [:group, 'group'].include?(cli_level) && hash[:primary]
          [:primary_group, hash.tap { |h| h.delete(:primary) }]
        else
          [cli_level, hash]
        end
      end

      attr_reader :cmd_instance, :args, :opts

      def initialize(cmd_instance, *args, **opts)
        @cmd_instance = cmd_instance
        @args = args
        @opts = opts
      end

      def run(method)
        if opts.empty?
          cmd_instance.public_send(method, *args)
        else
          cmd_instance.public_send(method, *args, **opts)
        end
      rescue Interrupt
        Log.warn_puts 'Received Interrupt!'
      rescue => e
        Log.fatal(e)
        raise e
      end
    end

    include CommandHelper

    def self.named_commander_proxy(level, method: nil, index: nil)
      method ||= (index || level)
      lambda do |name_and_args, commander_opts|
        CommanderProxy.named(self, level, name_and_args, commander_opts, index)
                      .run(method)
      end
    end

    def self.unnamed_commander_proxy(level, method: nil, index: nil)
      method ||= (index || level)
      lambda do |args, commander_opts|
        CommanderProxy.unnamed(self, level, args, commander_opts, index)
                      .run(method)
      end
    end

    def model_class
      case level
      when :cluster, 'cluster'
        require 'flight_metal/models/cluster'
        Models::Cluster
      when :group, 'group'
        require 'flight_metal/models/group'
        Models::Group
      when :primary_group, 'primary_group'
        require 'flight_metal/models/group'
        Models::Group
      when :node, 'node'
        require 'flight_metal/models/node'
        Models::Node
      when :machine
        require 'flight_metal/models/machine'
        Models::Machine
      else
        raise InternalError, <<~ERROR.chomp
          Unrecognised command level #{level}
        ERROR
      end
    end

    def is_primary?
      [:primary_group, 'primary_group'].include?(level)
    end

    def model_name_or_error
      is_missing = (model_name.nil? || model_name.empty?)
      if is_missing && [:cluster, 'cluster'].include?(level)
        Config.cluster
      elsif is_missing
        raise InternalError, <<~ERROR.chomp
          The #{level.to_s} name has not been set
        ERROR
      else
        model_name
      end
    end

    def read_model
      if model_class == Models::Cluster
        read_cluster
      elsif model_class == Models::Group
        read_group
      elsif model_class == Models::Node
        read_node
      elsif model_class == Models::Machine
        read_machine
      else
        raise InternalError
      end
    end

    def read_cluster
      Models::Cluster.read(model_name || Config.cluster)
    end

    def read_group
      Models::Group.read(Config.cluster, model_name_or_error)
    end

    def read_node
      Models::Node.read(Config.cluster, model_name_or_error)
    end

    def read_machine
      Models::Machine.read(Config.cluster, model_name_or_error)
    end

    def read_nodes
      require 'flight_metal/models/node'
      model = read_model
      if model.is_a?(Models::Node)
        [model]
      elsif [:primary_group, 'primary_group'].include?(level)
        model.read_primary_nodes
      else
        model.read_nodes
      end
    end

    def read_groups
      require 'flight_metal/models/group'
      case model = read_model
      when Models::Cluster
        model.read_groups
      when Models::Group
        [model]
      when Models::Node
        model.read_groups
      end
    end

    def read_models
      case index
      when :nodes, 'nodes'
        read_nodes
      when :groups, 'groups'
        read_groups
      when NilClass
        raise InternalError, <<~ERROR.chomp
          The command index target has not been set
        ERROR
      else
        raise InternalError, <<~ERROR.chomp
          Unrecognised command index target #{index}
        ERROR
      end
    end
  end

  class Command
    include CommandHelper
  end
end
