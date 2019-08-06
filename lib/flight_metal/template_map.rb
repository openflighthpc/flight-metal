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
  module TemplateMap
    HASH = {
      kickstart: { flag: 'kickstart', filename: 'kickstart.ks' },
      pxelinux: { flag: 'pxelinux', filename: 'pxelinux.cfg' },
      dhcp: { flag: 'dhcp', filename: 'dhcp.conf' },
      ipmi: { flag: 'ipmi', filename: 'ipmi.sh' },
      power_on: { flag: 'power-on', filename: 'power/on.sh' },
      power_off: { flag: 'power-off', filename: 'power/off.sh' },
      power_status: { flag: 'power-status', filename: 'power/status.sh' }
    }

    def self.keys
      HASH.keys
    end

    def self.path_method(key, sub: nil)
      :"#{key}_#{sub + '_' if sub}path"
    end

    def self.path_methods(sub: nil)
      HASH.keys.map { |k| [path_method(k, sub: sub), k] }
    end

    def self.lookup_key(raw)
      string = raw.to_s
      ifnone = -> { raise InvalidInput, "'#{string}' is not a valid type" }
      HASH.find(ifnone) { |_, v| string == v[:flag] }.first
    end

    def self.flag(key)
      HASH[key][:flag]
    end

    def self.find_filename(type)
      HASH[type][:filename]
    end

    def self.filename_hash
      HASH.map { |k, v| [k, v[:filename]] }
    end

    def self.flag_hash
      HASH.map { |k, v| [k, v[:flag]] }.to_h
    end

    module PathAccessors
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def define_path?(*methods)
          methods.map { |m| /_path\Z/.match?(m.to_s) ? m : "#{m}_path" }
                 .each do |method|
            define_method("#{method}?") do
              if path = self.public_send(method)
                File.exists?(path)
              else
                nil
              end
            end
          end
        end

        def define_type_path_shortcuts(sub: nil)
          type_method = TemplateMap.path_method('type', sub: sub)

          define_method(type_method) do |type|
            method = TemplateMap.path_method(type, sub: sub)
            public_send(method)
          end

          define_method(:"#{type_method}?") do |type|
            method = TemplateMap.path_method(type, sub: sub)
            public_send(:"#{method}?")
          end
        end
      end
    end
  end
end
