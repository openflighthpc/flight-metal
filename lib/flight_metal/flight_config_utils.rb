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

require 'flight_metal/errors'
require 'flight_config/globber'
require 'flight_config/updater'

# Override FlightConfig::Updater to generate sym_link
# Consider merging into FlightConfig
module FlightConfig
  class ConfigSymlinkBuilder
    def paths(&b)
      @paths ||= b
    end

    def validate(&b)
      @validate ||= b
    end

    def path_builder(&b)
      @path_builder ||= b
    end

    def glob_read(klass, *a, registry: nil, arity: nil)
      arity ||= klass.method(:path).arity
      globber = FlightConfig::Globber::Matcher.new(klass, arity, registry)

      Dir.glob(path_builder.call(*a))
         .map do |link|
        if File.exists? link
          model = globber.read(Pathname.new(link).readlink.to_s)
          if validate.call(model, link)
            model
          else
            # Remove invalid links
            FileUtils.rm link
            nil
          end
        else
          # Remove old links if they no longer exist
          FileUtils.rm link
          nil
        end
      end.reject(&:nil?)
    end
  end

  module UpdaterPatch
    def create_or_update(config, *a)
      super.tap do
        config.generate_indices if config.respond_to?(:generate_indices)
      end
    end
  end

  module Updater
    class << self
      self.prepend(UpdaterPatch)
    end
  end
end

module FlightMetal
  module FlightConfigUtils
    module ClassMethods
      def flag(name, fetch: nil, set: nil)
        if fetch.respond_to?(:call)
          define_method(name) { instance_exec(__data__.fetch(name), &fetch) }
        else
          define_method(name) { __data__.fetch(name) }
        end

        define_method("#{name}?") { send(name) ? true : false }

        define_method("#{name}=") do |raw|
          value = (set ? instance_exec(raw, &set) : raw)
          __data__.set("__#{name}_time__",  value: Time.now.to_i)
          if value.nil? || value == ''
            __data__.delete(name)
          else
            __data__.set(name, value: value)
          end
        end

        define_method(:"#{name}_time") do
          Time.at(__data__.fetch("__#{name}_time__") || 0)
        end
      end

      def has_indices(klass, &b)
        @indices ||= []
        @indices << [klass, b]
      end

      def indices
        @indices ||= []
        base = (defined?(super) ? super : [])
        [*base, *@indices]
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def generate_indices
      self.class.indices.each do |klass, block|
        instance_exec(klass.method(:create_or_update), &block)
      end
    end
  end
end

