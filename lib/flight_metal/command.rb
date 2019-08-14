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

  ScopedCommand = Struct.new(:level, :model_name) do
    CommanderProxy = Struct.new(:command_model, :instance_args, :commander_opts) do
      def run(method)
        opts = commander_opts.__hash__.dup.tap { |hash| hash.delete(:trace) }
        if opts.empty?
          command_model.public_send(method, *instance_args)
        else
          command_model.public_send(method, *instance_args, **opts)
        end
      rescue Interrupt
        Log.warn_puts 'Received Interrupt!'
      rescue => e
        Log.fatal(e)
        raise e
      end
    end

    include CommandHelper

    def self.named_commander_proxy(level, method: nil)
      method ||= level
      lambda do |args, commander_opts|
        cmd_obj = new(level, args.first)
        CommanderProxy.new(cmd_obj, args[1..-1], commander_opts).run(method)
      end
    end

    def self.unnamed_commander_proxy(level, method: nil)
      method ||= level
      lambda do |args, commander_opts|
        cmd_obj = new(level)
        CommanderProxy.new(cmd_obj, args, commander_opts).run(method)
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
      when :node, 'node'
        require 'flight_metal/models/node'
        Models::Node
      else
        raise InternalError, <<~ERROR.chomp
          Unrecognised command level #{level}
        ERROR
      end
    end

    def model_name_or_error
      has_name = !(model_name.nil? || model_name.empty?)
      if has_name
        model_name
      else
        raise InternalError, <<~ERROR.chomp
          The #{level.to_s} name has not been set
        ERROR
      end
    end

    def read_model
      name = model_name_or_error # Ensure the error check has occurred
      if model_class == Models::Cluster
        Models::Cluster.read(Config.cluster)
      else
        model_class.read(Config.cluster, name)
      end
    end
  end

  class Command
    include CommandHelper
  end
end
