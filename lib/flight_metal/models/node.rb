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
require 'flight_metal/models/nodeattr'
require 'flight_metal/errors'
require 'flight_metal/macs'
require 'flight_metal/system_command'
require 'flight_manifest'

module FlightMetal
  module Models
    class Node
      include FlightConfig::Deleter
      include FlightConfig::Accessor
      include FlightConfig::Links

      # The Builder class adds the additional fields
      class Builder < FlightManifest::Node
        property :base, default: -> { Dir.pwd }
        property :rebuild, default: true
        property :built, default:  false
        property :cluster
        property :ip, from: :build_ip

        # The following redefine methods on FlightManifest::Node, your usage may vary
        property :name, default: ''

        def initialize(*a)
          super
          # NOTE: SystemCommand is meant to take a Models::Node NOT a Manifest/Builder
          # This is a bit of a hack, however as manifest responds to :name
          # `fqdn_and_ip` still works. Consider refactoring
          unless build_ip && fqdn
            output = SystemCommand.new(self).fqdn_and_ip.first
            fqdn, build_ip =  if output.exit_0?
                                output.stdout.split
                              else
                                [nil, nil]
                              end
            self.fqdn ||= fqdn if fqdn
            self.build_ip ||= build_ip if build_ip
          end
        end

        # HACK: Make `groups` appear as a property even through it wraps primary_group
        # and secondary_groups. This is because `Hashie::Trash` doesn't have the ability
        # to transform values based on multiple keys
        self.properties << :groups

        def [](attr)
          attr == :groups ? self.groups : super
        end

        def []=(attr, value)
          attr == :groups ? self.groups = value : super
        end

        def groups
          [primary_group, *secondary_groups]
        end

        def groups=(grps)
          self.primary_group = grps.first
          self.secondary_groups = grps[1..-1]
        end

        def create
          Models::Node.create(cluster, name) do |node|
            store_model_templates(node)
            update_model_attributes(node)
          end
          Models::Nodeattr.create_or_update(cluster) do |attr|
            attr.add_nodes(name, groups: groups)
          end
        end

        private

        def update_model_attributes(node)
          [
            :ip, :fqdn, :bmc_ip, :bmc_username, :bmc_password, :gateway_ip,
            :rebuild, :built
          ].each { |a| node.send("#{a}=", self.send(a)) }
        end

        def store_model_templates(node)
          pxelinux_src = pxelinux_file.expand_path(base)
          kickstart_src = kickstart_file.expand_path(base)
          raise_unless_file('pxelinux', pxelinux_src)
          raise_unless_file('kickstart', kickstart_src)
          FileUtils.mkdir_p File.dirname(node.pxelinux_template_path)
          FileUtils.mkdir_p File.dirname(node.kickstart_template_path)
          FileUtils.cp  pxelinux_src, node.pxelinux_template_path
          FileUtils.cp  kickstart_src, node.kickstart_template_path
        end

        def raise_unless_file(name, path)
          return if path.file?
          raise InvalidInput, <<~ERROR.chomp
            The #{name} input is not a regular file: '#{path.to_s}'
          ERROR
        end
      end

      def self.path(cluster, name)
        File.join(
          Config.content_dir, 'clusters', cluster, 'var/nodes',
          name, 'etc/config.yaml'
        )
      end
      define_input_methods_from_path_parameters

      def self.exists?(*a)
        Pathname.new(new(*a).path).file?
      end

      def self.delete!(*a)
        delete(*a) do |node|
          FileUtils.rm_f node.pxelinux_template_path
          FileUtils.rm_f node.kickstart_template_path
          Models::Nodeattr.create_or_update do |attr|
            attr.remove_nodes(node.name)
          end
          true
        end
      end

      include FlightConfig::Updater
      include FlightConfig::Globber

      include FlightMetal::FlightConfigUtils

      flag :built
      flag :rebuild
      flag :mac, set: ->(original_mac) do
        original_mac.tap do |mac|
          if mac.nil? || mac.empty?
            next
          elsif node = Macs.new(__registry__).find(mac)
            raise InvalidModel, <<~ERROR.squish
              Failed to update mac address '#{mac}' as it is already taken by:
              node '#{node.name}' in cluster '#{node.cluster}'
            ERROR
          end
        end
      end

      data_writer(:bmc_user)
      data_writer(:bmc_password)
      data_writer(:bmc_ip)

      data_reader(:bmc_user) { links.cluster.bmc_user }
      data_reader(:bmc_password) { links.cluster.bmc_password }

      alias_method :bmc_username, :bmc_user
      alias_method :bmc_username=, :bmc_user=

      data_reader :bmc_ip

      data_reader(:ip)
      data_reader(:fqdn)
      data_writer(:ip)
      data_writer(:fqdn)

      data_reader(:gateway_ip) { links.cluster.gateway_ip }
      data_writer :gateway_ip

      define_link(:cluster, Models::Cluster) { [cluster] }
      define_link(:nodeattr, Models::Nodeattr) { [cluster] }

      def initialize(*a, **h)
        super
      end

      def groups
        links.nodeattr.groups_for_node(name)
      end

      def primary_group
        groups.first
      end

      def secondary_groups
        groups[1..-1]
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

      def pxelinux_cfg?
        File.exists?(pxelinux_cfg_path)
      end

      def pxelinux_cfg_path
        File.join(Config.tftpboot_dir,
                  'pxelinux.cfg',
                  '01-' + mac.downcase.gsub(':', '-')
                 )
      end

      def pxelinux_template?
        File.exists? pxelinux_template_path
      end

      def pxelinux_template_path
        File.join(template_dir, 'pxelinux.cfg', 'pxe_bios')
      end

      def pxelinux?
        pxelinux_template? || pxelinux_cfg?
      end

      def kickstart?
        kickstart_template? || kickstart_www?
      end

      def kickstart_www_path
        File.join(Config.kickstart_dir, cluster, "#{name}.ks")
      end

      def kickstart_www?
        File.exists? kickstart_www_path
      end

      def kickstart_template_path
        File.join(template_dir, "#{name}.ks")
      end

      def kickstart_template?
        File.exists? kickstart_template_path
      end

      def ipmi_opts
        "-H #{name}.bmc -U #{bmc_user} -P #{bmc_password}"
      end
    end
  end
end
