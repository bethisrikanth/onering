module Automation
  module Tasks
    module Core
      class Log < Base
        def run(request)
          line = "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S %z")}] #{@data}"

          if File.writable?(File.dirname(opt(:file)))
            File.open(opt(:file), 'a+') do |file|
              file.puts(line)
            end
          else
            log(line)
          end
        end
      end
    end
  end
end
