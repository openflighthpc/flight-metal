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

require 'active_support/concern'

module FlightMetal
  module Models
    module Concerns
      module HasParams
        extend ActiveSupport::Concern

        included do
          data_reader(:params) do |hash|
            hash = (hash || {}).symbolize_keys
            self.class.named_param_keys.each do |key|
              value = read_named_param(key)
              value.nil? ? hash.delete(key) : hash[key] = value
            end
            hash
          end

          data_writer(:params) do |hash|
            hash = hash.to_h.dup.symbolize_keys
            update_keys = hash.keys & self.class.named_param_keys
            update_keys.each do |key|
              write_named_param(key, hash[key])
              hash.delete(key)
            end
            self.class.reserved_param_keys do |key|
              unless hash.delete(key).nil?
                Log.warn_puts <<~MSG.squish
                  Cowardly refusing to overwrite '#{name}' reserved parameter
                  key: #{key}
                MSG
              end
            end
            hash
          end
        end

        class_methods do
          def named_param_reader(name, &b)
            named_params[:reader][name.to_sym] = b
          end

          def named_param_writer(name, &b)
            named_params[:writer][name.to_sym] = b
          end

          def named_params
            @named_params ||= { reader: {}, writer: {}, reserved: [] }
          end

          def named_param_keys
            reader_keys = named_params[:reader].keys
            writer_keys = named_params[:writer].keys
            reader_keys.union(writer_keys)
          end

          def reserved_param_keys
            named_params[:reserved]
          end

          def reserved_param_reader(key, &b)
            named_params[:reserved] << key
            named_param_reader(key, &b)
          end
        end

        def merge_params!(hash)
          self.params = self.params.merge(hash)
        end

        def read_named_param(key)
          model_value = send(key)
          if block = self.class.named_params[:reader][key]
            instance_exec(model_value, &block)
          else
            model_value
          end
        end

        def write_named_param(key, raw_value)
          return if self.class.reserved_param_keys.include?(key)
          current_value = read_named_param(key)
          return if current_value == raw_value
          model_value = if block = self.class.named_params[:writer][key]
            instance_exec(raw_value, &block)
          else
            raw_value
          end
          send("#{key}=", model_value)
        end

        def reserved_params
          self.class.reserved_param_keys.map do |key|
            [key, read_named_param(key)]
          end.to_h
        end

        def non_reserved_params
          h = params.dup.tap do |hash|
            self.class.reserved_param_keys.each { |k| hash.delete(k) }
          end
          h
        end
      end
    end
  end
end
