module Automation
  class LogTask < Task
    def run(request)
      line = "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S %z")}] #{@data}"

      if File.writable?(opt(:file))
        File.open(opt(:file), 'a+') do |file|
          file.puts(line)
        end
      else
        STDOUT.puts(line)
      end
    end
  end
end
