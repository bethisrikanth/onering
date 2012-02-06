class PhysicalRack
  include Mongoid::Document
  field :index, :type => Integer
  field :name, :type => String
  has_many :physical_hosts
  belongs_to :datacenter

  validates :index, :numericality => { :only_integer => true }   
  validates_presence_of :name
  validates_associated :datacenter
  
  def self.list_options
    PhysicalRack.all.map {|r| [r.id, r.name]}
  end
end
