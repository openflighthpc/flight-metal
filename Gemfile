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

source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

gem 'activesupport'
gem 'commander-openflighthpc'

# The experimental FlightRegistry code modifies FlightConfig. It should be moved
# to this gem when stabilised
gem 'flight_config', '0.2.0'

gem 'flight_manifest', '0.1.2'
gem 'rubyzip'
gem 'pcap', github: 'alces-software/ruby-pcap'
gem 'net-dhcp'
gem 'highline'
gem 'hashie'
gem 'parallel'
gem 'tty-markdown'
gem 'tty-editor'
gem 'nodeattr_utils'

group :development do
  gem 'pp'
  gem 'pry'
  gem 'pry-byebug'
end

