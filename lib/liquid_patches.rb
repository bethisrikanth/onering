# Copyright 2012 Outbrain, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'liquid'

module App
  module Liquid
    module Filters
      def or(*args)
        args.each{|arg| return arg if arg }
        nil #else
      end

      def and(*args)
        args[1..-1].each{|arg| return nil unless arg }
        args.first
      end
    end
  end
end

Liquid::Template.register_filter(App::Liquid::Filters)