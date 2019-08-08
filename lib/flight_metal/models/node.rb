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

require 'flight_config'
require 'flight_metal/registry'
require 'flight_metal/models/cluster'
require 'flight_metal/models/group'
require 'flight_metal/models/nodeattr'
require 'flight_metal/errors'
require 'flight_metal/macs'
require 'flight_metal/system_command'
require 'flight_manifest'
require 'flight_metal/template_map'

module FlightMetal
  module Models
    class Node
      include FlightConfig::Updater
      include FlightConfig::Globber
      include FlightConfig::Deleter
      include FlightConfig::Accessor
      include FlightConfig::Links

      include TemplateMap::PathAccessors

      include FlightMetal::FlightConfigUtils

      def self.join(cluster, name, *a)
        Models::Cluster.join(cluster, 'var', 'nodes', name, *a)
      end

      def self.path(cluster, name)
        join(cluster, name, 'etc', 'config.yaml')
      end
      define_input_methods_from_path_parameters

      def self.exists?(*a)
        Pathname.new(new(*a).path).file?
      end

      def self.delete!(*a)
        delete(*a) do |node|
          FileUtils.rm_rf node.join('lib')
          Models::Nodeattr.create_or_update(node.cluster) do |attr|
            attr.remove_nodes(node.name)
          end
          true
        end
      end

      flag :built
      flag :rebuild

      data_reader(:params) do |hash|
        hash = (hash || {}).symbolize_keys
        SpecialParameters.new(self).read(**hash)
      end
      data_writer(:params) do |raw|
        hash = raw.to_h.dup.symbolize_keys
        SpecialParameters.new(self).write(hash)
        hash.delete_if do |k, _v|
          reserved_params.keys.include?(k).tap do |bool|
            Log.warn_puts <<~MSG.chomp if bool
              Cowardly refusing to overwrite '#{name}' reserved parameter key: #{k}
            MSG
          end
        end
      end

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

      define_link(:cluster, Models::Cluster) { [cluster] }
      define_link(:nodeattr, Models::Nodeattr) { [cluster] }
      define_link(:group, Models::Group) { [cluster, primary_group] }

      TemplateMap.path_methods.each do |method, type|
        define_method(method) do
          join('libexec', TemplateMap.find_filename(type))
        end
        define_path?(method)
      end
      define_type_path_shortcuts

      TemplateMap.path_methods(sub: 'template').each do |method, type|
        define_method("#{type}_template_model") do
          links.group.type_path?(type) ? links.group : links.cluster
        end

        define_method(method) do
          type_template_model(type).type_path(type)
        end
        define_path?(method)
      end
      define_type_path_shortcuts(sub: 'template')

      def type_template_model(type)
        public_send("#{type}_template_model")
      end

      def pxelinux_system_path
        if mac
          File.join(Config.tftpboot_dir,
                    'pxelinux.cfg',
                    '01-' + mac.downcase.gsub(':', '-'))
        else
          nil
        end
      end

      def kickstart_system_path
        File.join(Config.kickstart_dir, cluster, name + '.ks')
      end

      def dhcp_system_path
        File.join(Config.dhcpd_dir, name + '-dhcpd.conf')
      end

      define_type_path_shortcuts(sub: 'system')

      [:kickstart, :pxelinux, :dhcp].each do |type|
        define_path?(TemplateMap.path_method(type, sub: 'system'))

        define_method("#{type}_status") do |error: true|
          if type_path?(type) && type_system_path?(type, symlink: true)
            rendered = Pathname.new(type_path(type))
            system = Pathname.new(type_system_path(type))
            if system.symlink? && File.identical?(system.readlink, rendered)
              :installed
            elsif error && system.symlink?
              raise InvalidModel, <<~ERROR.chomp
                '#{name}' system file is linked incorrectly. Fix the link and try again
                Link Source: #{system}
                Correct:     #{system.readlink}
                Incorrect:   #{rendered}
              ERROR
            elsif error
              raise InvalidModel, <<~ERROR.chomp
                '#{name}' system file already exists, please remove it and try again
                File: #{system}
              ERROR
            else
              :invalid
            end
          elsif type_path?(type)
            :pending
          elsif type_template_path?(type)
            :renderable
          else
            :missing
          end
        end
      end

      [:ipmi, :power_on, :power_off, :power_status].each do |type|
        define_method("#{type}_status") do |error: true|
          if type_path?(type)
            :installed
          elsif type_template_path?(type)
            :renderable
          else
            :missing
          end
        end
      end

      def type_status(type, error: true)
        public_send("#{type}_status", error: error)
      end

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

      def type_buildable?(type)
        case type_status(type, error: false)
        when :installed
          true
        when :pending
          true
        else
          false
        end
      end

      # Contains all the parameters that can be rendered against
      def render_params
        params.merge(reserved_params)
      end

      # Quasi-parameters that are saved on the model directly. This allows
      # integration code to be ran on the model
      SpecialParameters = Struct.new(:node) do
        def to_h
          read
        end

        def read(**kwargs)
          keys.each do |key|
            kwargs.delete(key)
            value = send(key)
            kwargs[key] = value unless value.nil?
          end
          kwargs
        end

        def write(**kwargs)
          keys.each { |k| setter(k, kwargs.delete(k)) if kwargs.key?(k) }
        end

        private

        delegate :mac, :mac=, to: :node

        def keys
          [:mac, :groups]
        end

        def groups
          node.groups.join(',')
        end

        # Do not allow the groups list to be updated via a parameter
        # This action is not supported as it requires updating the nodeattr file
        # This sort of destructive action should be explicitly handled in the CLI
        def groups=(a)
          return if a.nil? || a == groups
          raise InvalidAction, <<~ERROR.squish
            An unexpected error has occurred. Failed to update '#{node.name}'
            groups list
          ERROR
        end

        def setter(key, value)
          send("#{key}=", value)
        end
      end

      def special_params
        SpecialParameters.new(self).to_h
      end

      # Parameters that can not be set by the user. They will be filtered
      # from the params list on save.
      def reserved_params
        { name: name, cluster: cluster, primary_group: primary_group }
      end

      def join(*a)
        self.class.join(*__inputs__, *a)
      end

      def groups
        links.nodeattr.groups_for_node(name)
      end

      def primary_group
        groups.first
      end

      # TODO: Look how this integrates into FlightConfig
      # NOTE: This method does not share a registry and will cause all files to
      # reload. Consider refactoring?
      def update(&b)
        new_node = self.class.update(*__inputs__, &b)
        self.instance_variable_set(:@__data__, new_node.__data__)
      end

      def base_dir
        File.dirname(File.dirname(path))
      end

      def template_dir
        File.join(base_dir, 'var/templates')
      end

      def ipmi_opts
        "-H #{name}.bmc -U #{bmc_username} -P #{bmc_password}"
      end
    end
  end
end
