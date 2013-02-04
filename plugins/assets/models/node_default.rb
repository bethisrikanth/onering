require 'model'
require 'assets/models/device'
require 'liquid_patches'

class NodeDefault < App::Model::Base
  set_collection_name "node_defaults"

  TEMPLATE_ROOT = File.expand_path(File.join(ENV['PROJECT_ROOT'], 'config', 'plugins', 'assets', 'defaults'))
  ::Liquid::Template.file_system = ::Liquid::LocalFileSystem.new(TEMPLATE_ROOT)

  timestamps!

  key :devices,  Array
  key :priority, Integer
  key :defaults, Hash

  many :devices, :in => :devices

  def to_h
    rv = super
    @_templates ||= {}

    rv.each_recurse do |key, value, path|
      path = path.join('.')

    # get or create/cache/get precomputed template
      if value.is_a?(String)
        unless @_templates.get(path)
          @_templates.set(path, Liquid::Template.parse(value))
        end
        
        tpl = @_templates.get(path)
      end

    # render the value if a template exists for it
      if tpl
        rv.set(path, (tpl.render(rv).to_s.strip.chomp rescue nil))
      end
    end

    rv
  end          
end
