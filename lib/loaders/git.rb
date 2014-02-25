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

module Onering
  class PluginLoader
    require 'git'
    require 'uri'

    def self.git(repo)
      base = temp_root()

      if File.writable?(base)
        tmpdir  = File.join(base, Digest::SHA256.new.update(repo).hexdigest)

        if File.directory?(tmpdir)
        else
          Git.clone(repo, tmpdir)

          if (ringfile = File.exists?(File.join(tmpdir, 'Ringfile')))
            Onering::PluginLoader.eval_ringfile(ringfile)
          else
            Onering::Logger.fatal("Git repository at #{repo} is not a valid plugin, missing Ringfile", "Onering::PluginLoader")
          end
        end

        FileUtils.rm_rf(tmpdir)

      else
        Onering::Logger.fatal("Cannot load plugin git://#{repo}, temporary directory #{base} not writable", "Onering::PluginLoader")
      end

      return true
    end
  end
end
