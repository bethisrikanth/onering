require 'controller'
require 'assets/models/asset'
require 'automation/lib/task'

Automation::Tasks::Task.load_all()

module App
  class Base < Controller
    include Helpers


    namespace '/api/automation' do
      namespace '/tasks' do
        helpers do
          def run_task(name, *args)
            task = Automation::Tasks::Task.as_task(name)
            return 404 unless task

            case params[:priority].to_s.downcase.to_sym
            when :critical
              Automation::Tasks::Task.run_critical(name, *args)
            when :high
              Automation::Tasks::Task.run_high(name, *args)
            when :low
              Automation::Tasks::Task.run_low(name, *args)
            else
              Automation::Tasks::Task.run(name, *args)
            end

            return 200
          end
        end

        %w{
          /run/:name/?
          /run/:name/*/?
        }.each do |r|
          get r do
            if params[:splat].first.nil?
              run_task(params[:name])
            else
              run_task(params[:name], *params[:splat].first.split('/'))
            end

          end

          post r do
            run_task(params[:name], MultiJson.load(request.env['rack.input'].read))
          end
        end
      end
    end
  end
end
