class PhysicalRack
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Versioning
  max_versions 5

  field :index, :type => Integer
  field :name, :type => String
  field :number_of_us, :type => Integer

  has_many :physical_hosts
  belongs_to :datacenter
  has_many :audits, :as => :entity

  index :name, unique: true
  index :index

  validates_numericality_of :number_of_us, :only_integer => true, :allow_blank => true
  validates_numericality_of :index, :only_integer => true
  validates_presence_of :name
  validates_associated :datacenter
  
  def self.list_options
    PhysicalRack.all.map {|r| [r.id, r.name]}
  end

  def to_param
    (name.gsub('.', '-') if name) || id.to_s
  end

  # This adds a list of empty hosts to the rack where the rack has gaps in the U's list
  def add_missing_hosts
    all_us = physical_hosts.asc(:u).map(&:u)
    last_u = all_us.last
    if last_u
      (1..last_u).each do |u_index|
        if not all_us.include?(u_index)
          host = PhysicalHost.new(name: "", n: 0, u: u_index)
          self.physical_hosts << host
        end
      end
      save!
    end
  end

  # Updats this rack from the given row (updates one specific host)
  def update_host_from_csv(row)
    host_id = row[0]
    host_u = row[1]
    host_n = row[2]
    host_ob_name = row[3]
    host_name = row[4]
    parent_host_name = row[5]
    pdu1_name = row[6]
    pdu1_voltage = row[7]
    pdu1_amps = row[8]
    pdu2_name = row[9]
    pdu2_voltage = row[10]

    host = host_id.nil? ? PhysicalHost.new : PhysicalHost.find(host_id)
    physical_hosts << host unless physical_hosts.include?(host)
    host.u = host_u
    host.n = host_n
    host.ob_name = host_ob_name
    host.name = host_name

    if parent_host_name
      parent_host = PhysicalHost.find_by_name(parent_host_name)
      if not parent_host.child_hosts.include?(host)
        parent_host.child_hosts << host
      end
    else
      host.parent_host = nil
    end

    is_new = host.new?
    changed = host.changed? and not is_new
    success = host.save

    {updates: changed ? 1 : 0, insertions: is_new ? 1 : 0, errors: success ? 0 : 1}
  end
end
