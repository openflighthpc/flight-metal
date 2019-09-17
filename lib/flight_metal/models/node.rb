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

require 'flight_metal/models/machine'
require 'flight_metal/models/cluster'
require 'flight_metal/models/group'
require 'flight_metal/macs'
require 'flight_metal/system_command'
require 'flight_metal/models/concerns/has_params'

module FlightMetal
  module Models
    class Node < Model
      # Must be required after the class declaration
      require 'flight_metal/models/node/has_groups'

      include Concerns::HasParams
      include HasGroups

      def self.join(cluster, name, *a)
        Models::Cluster.join(cluster, 'var', 'nodes', name, *a)
      end

      def self.path(cluster, name)
        join(cluster, name, 'etc', 'config.yaml')
      end
      define_input_methods_from_path_parameters

      def self.delete!(*a)
        delete(*a) do |node|
          FileUtils.rm_rf node.join('lib')
          true
        end
      end

      reserved_param_reader(:mac)

      reserved_param_reader(:other_groups) do |groups|
        groups.empty? ? nil : groups.join(',')
      end
      reserved_param_reader(:primary_group)

      reserved_param_reader(:name)
      reserved_param_reader(:cluster)
      reserved_param_reader(:groups) do |groups|
        groups.join(',')
      end

      flag :built
      flag :rebuild

      data_reader(:mac)
      data_writer(:mac) do |hwaddr|
        if hwaddr.nil? || hwaddr.empty?
          nil
        elsif self.mac == hwaddr
          mac
        elsif other = Macs.new(__registry__).find(hwaddr)
          raise InvalidModel, <<~ERROR.chomp
            Could not update mac address as it is currently being used in:
              - cluster: #{other.cluster}
              - name: #{other.name}
          ERROR
        else
          hwaddr.to_s
        end
      end

      def template_path(type)
        TemplateMap.raise_unless_valid_type(type)
        join('templates', TemplateMap.find_filename(type))
      end

      def template?(type)
        File.exists? template_path(type)
      end

      # TemplateMap.path_methods.each do |method, type|
      #   define_method(method) do
      #     join('libexec', TemplateMap.find_filename(type))
      #   end
      #   define_path?(method)
      # end
      # define_type_path_shortcuts

      # TemplateMap.path_methods(sub: 'template').each do |method, type|
      #   define_method("#{type}_template_model") do
      #     return read_primary_group if read_primary_group.type_path?(type)
      #     return read_cluster if read_cluster.type_path?(type)
      #   end

      #   define_method(method) do
      #     type_template_model(type)&.type_path(type)
      #   end
      #   define_path?(method)
      # end
      # define_type_path_shortcuts(sub: 'template')

      # def type_template_model(type)
      #   public_send("#{type}_template_model")
      # end

      # def pxelinux_system_path
      #   if mac
      #     File.join(Config.tftpboot_dir,
      #               'pxelinux.cfg',
      #               '01-' + mac.downcase.gsub(':', '-'))
      #   else
      #     nil
      #   end
      # end

      # def kickstart_system_path
      #   File.join(Config.kickstart_dir, name + '.ks')
      # end

      # def dhcp_system_path
      #   File.join(Config.dhcpd_dir, name + '.conf')
      # end

      # define_type_path_shortcuts(sub: 'system')

      # [:kickstart, :pxelinux, :dhcp].each do |type|
      #   define_path?(TemplateMap.path_method(type, sub: 'system'))

      #   define_method("#{type}_status") do |error: true|
      #     if type_path?(type) && type_system_path?(type, symlink: true)
      #       rendered = Pathname.new(type_path(type))
      #       system = Pathname.new(type_system_path(type))
      #       if system.symlink? && File.identical?(system.readlink, rendered)
      #         :installed
      #       elsif error && system.symlink?
      #         raise InvalidModel, <<~ERROR.chomp
      #           '#{name}' system file is linked incorrectly. Fix the link and try again
      #           Link Source: #{system}
      #           Correct:     #{system.readlink}
      #           Incorrect:   #{rendered}
      #         ERROR
      #       elsif error
      #         raise InvalidModel, <<~ERROR.chomp
      #           '#{name}' system file already exists, please remove it and try again
      #           File: #{system}
      #         ERROR
      #       else
      #         :invalid
      #       end
      #     elsif type_path?(type)
      #       :pending
      #     elsif type_template_path?(type)
      #       :renderable
      #     else
      #       :missing
      #     end
      #   end
      # end

      # [:ipmi, :power_on, :power_off, :power_status].each do |type|
      #   define_method("#{type}_status") do |error: true|
      #     if type_path?(type)
      #       :installed
      #     elsif type_template_path?(type)
      #       :renderable
      #     else
      #       :missing
      #     end
      #   end
      # end

      # def type_status(type, error: true)
      #   public_send("#{type}_status", error: error)
      # end

      def mac?
        !mac.nil?
      end

      def buildable?
        mac? && rebuild? && all_types_buildable?
      end

      def all_types_buildable?
        [:kickstart, :pxelinux, :dhcp].map do |type|
          type_buildable?(type)
        end.reduce { |memo, bool| memo && bool }
      end

      # def type_buildable?(type)
      #   case type_status(type, error: false)
      #   when :installed
      #     true
      #   when :pending
      #     true
      #   else
      #     false
      #   end
      # end

      # TODO: Remove render_params as it is now equivalent to params
      def render_params
        params
      end

      def read_cluster
        Models::Cluster.read(cluster, registry: __registry__)
      end

      def read_machine
        Models::Machine.read(*__inputs__, registry: __registry__)
      end

      # TODO: Look how this integrates into FlightConfig
      # NOTE: This method does not share a registry and will cause all files to
      # reload. Consider refactoring?
      def update(&b)
        new_node = self.class.update(*__inputs__, &b)
        self.instance_variable_set(:@__data__, new_node.__data__)
      end
    end
  end
end
