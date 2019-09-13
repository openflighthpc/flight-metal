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

module FlightMetal
  module Commands
    class Update < ScopedCommand
      Params = Struct.new(:params) do
        def merge_hash
          params.select { |p| /\A\w+=.*/.match?(p) }
                .map { |p| p.split('=', 2) }
                .to_h
                .symbolize_keys
        end

        def delete_keys
          params.select { |p| /\A\w+!/.match?(p) }
                .map { |p| p[0..-2].to_sym }
        end

        def update_model(model)
          model.params = model.params.dup.tap do |hash|
            hash.merge!(merge_hash)
            delete_keys.each { |k| hash.delete(k) }
          end
        end
      end

      command_require 'flight_metal/models/node', 'tty-editor'

      def params(*params)
        model_class.update(*read_model.__inputs__) do |model|
          Params.new(params).update_model(model)
        end
      end

      def params_editor
        model_class.update(*read_model.__inputs__) do |model|
          yaml = YAML.dump(model.non_reserved_params)
          Tempfile.open("#{model.name}-parameters", '/tmp') do |file|
            file.write(yaml)
            file.rewind
            TTY::Editor.open(file.path)
            model.params = YAML.safe_load(file.read, permitted_classes: [Symbol])
          end
        end
      end

      # def group(*params)
      #   Models::Group.update(Config.cluster, model_name_or_error) do |group|
      #     Params.new(params).update_model(group)
      #   end
      # end

      # def node(*params, rebuild: nil)
      #   rebuild = if rebuild.nil?
      #               nil
      #             elsif [false, 'false'].include?(rebuild)
      #               false # Treat 'false' as false
      #             else
      #               true
      #             end
      #   Models::Node.update(Config.cluster, model_name_or_error) do |node|
      #     Params.new(params).update_model(node)
      #     node.rebuild = rebuild unless rebuild.nil?
      #   end
      # end
    end
  end
end
