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

require 'flight_metal/errors'
require 'flight_config/globber'

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

      def data_writer(key)
        define_method("#{key}=") do |value|
          if value.nil? || value == ''
            __data__.delete(key)
          else
            __data__.set(key, value: value)
          end
        end
      end

      def data_reader(key, &b)
        define_method(key) { __data__.fetch(key) { instance_exec(&b) if b } }
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def update
      arity = self.method(:initialize).arity
      args = FlightConfig::Globber::Matcher.new(self.class, arity).args(path)
      self.class.update(*args) do |obj|
        self.instance_variable_set(:@__data__, obj.__data__)
        obj.__registry__ = self.__registry__
        yield obj if block_given?
      end
      self
    end

    def __registry__=(reg)
      raise InternalError, <<~ERROR unless reg.is_a?(Registry)
        The model __registry__ must be a FlightMetal::Registry
      ERROR
      @__registry__ = reg
    end

    def __registry__
      @__registry__ ||= Registry.new
    end
  end

  class Registry
    def read(klass, *args)
      class_hash = (cache[klass] ||= {})
      arity_hash = (class_hash[args.length] ||= {})
      last_arg = args.pop
      last_hash = args.reduce(arity_hash) { |hash, arg| hash[arg] ||= {} }
      last_hash[last_arg] ||= first_read(klass, *args, last_arg)
    end

    private

    def cache
      @cache ||= {}
    end

    def first_read(klass, *args)
      klass.read(*args).tap do |model|
        model.__registry__ = self if model.respond_to?(:"__registry__=")
      end
    end
  end
end

