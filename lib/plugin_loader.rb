module Onering
  class PluginLoader
    def self.eval_ringfile(file, &block)
      if block_given?
        Onering::Logger.debug("Evaluating Ringfile from block", "Onering::PluginLoader")
        content = yield
      else
        Onering::Logger.debug("Loading Ringfile at #{file}", "Onering::PluginLoader")
        content = File.open(file).read()
      end

      if content
        eval(content, binding)
      end
    end
  end
end


# load the loaders
Dir[File.join(File.dirname(__FILE__), 'loaders', '*.rb')].each do |p|
  p = File.basename(p, '.rb')

  begin
    Onering::Logger.debug("Loading plugin loader #{p}", "Onering")
    require "loaders/#{p}"
  rescue LoadError
    Onering::Logger.warn("Unable to load plugin loader #{p}", "Onering")
    next
  end
end