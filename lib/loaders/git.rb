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
