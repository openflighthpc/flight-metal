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

require 'erb'
require 'tty-editor'
require 'tty-markdown'
require 'flight_metal/log'
require 'ostruct'

module FlightMetal
  class Templator
    class NilStruct < OpenStruct
      def initialize
        super(nil)
      end

      def respond_to?(_s)
        true
      end
    end

    class TemplatorDelegator < SimpleDelegator
      def initialize(obj)
        self.__setobj__(obj)
      end

      def get_binding
        binding
      end

      def nil_to_null(value)
        value.nil? ? 'null' : value
      end

      def catch_error
        yield
      rescue => e
        Log.error e
        'Error (See Logs)'
      end
    end

    attr_reader :erb_binding

    def initialize(obj = nil)
      obj = (obj.nil? ? NilStruct.new : obj)
      @erb_binding = TemplatorDelegator.new(obj).get_binding
    end

    def render(text)
      ERB.new(text, nil, '-').result(erb_binding)
    end

    def edit(text)
      editor = TTY::Editor.new(content: render(text))
      editor.open
      File.read(editor.escape_file)
    end

    def edit_yaml(text)
      YAML.safe_load(edit(text), symbolize_names: true)
    end

    def yaml(text)
      YAML.safe_load(render(text), symbolize_names: true)
    end

    def markdown(text)
      TTY::Markdown.parse(render text)
    end
  end
end
