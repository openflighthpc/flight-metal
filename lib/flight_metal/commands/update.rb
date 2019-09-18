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

        def update!(hash)
          hash.merge!(merge_hash)
          delete_keys.each { |k| hash.delete(k) }
          hash
        end
      end

      command_require 'flight_metal/models/node', 'tty-editor', 'tempfile'

      def node_editor
        Models::Node.update(*read_node.__inputs__) do |node|
          # NOTE: In both cases the yaml keys are "converted" to string format
          # The leading : is a rubyish thing that makes them a symbol. However
          # this is not formally part of the YAML spec. YAY RUBY
          static_yaml = YAML.dump(node.static_params)
                            .split("\n")[1..-1] # Remove the header line
                            .map { |y| y.sub(/\A:?/, '# ') } # Make it a comment
                            .join("\n")
          other_yaml = YAML.dump(node.other_params)
                           .split("\n")[1..-1]
                           .map { |y| y.sub(/\A:?/, '') }
                           .join("\n")
          Tempfile.open("edit-#{node.name}-other-parameters", '/tmp') do |file|
            file.write <<~YAML.chomp
              # Edit the file to update the other parameters for node #{node.name}

              # The following parameters are static to the node and can not be
              # modified by 'node edit':

              # STATIC PARAMETERS:
              #{static_yaml}

              # The following are the existing parameters
              # Adding additional keys will add them as parameters
              # Similarly, removing keys will permanently delete the parameter

              # OTHER PARAMETERS
              #{other_yaml.empty? ? "# No other parameters found" : other_yaml}
            YAML
            file.rewind
            TTY::Editor.open(file.path)
            node.other_params = YAML.safe_load(file.read, permitted_classes: [Symbol])
          end
        end
      end

      def node(*param_strs, mac: nil, rebuild: nil)
        # Allow the rebuild flag to be string 'false'
        rebuild  = if rebuild.nil?
                     nil
                   elsif [false, 'false'].include?(rebuild)
                     false
                   else
                     true
                   end
        Models::Node.update(*read_node.__inputs__) do |node|
          builder = Params.new(param_strs)
          node.other_params = builder.update!(node.other_params.dup)
          node.mac = mac if mac
          node.rebuild = rebuild unless rebuild.nil?
        end
      end
    end
  end
end
