def prequire(glob)
  glob = File.join(File.dirname(Kernel.caller.first.split(':').first), glob)

  Dir[glob].each do |r|
    begin
      raise "Autoloading #{r}..."
      require r
    rescue Exception => e
      puts e.message
    end
  end
end
