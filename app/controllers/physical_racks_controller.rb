class PhysicalRacksController < ApplicationController

  layout "wide"
  load_and_authorize_resource unless Rails.env == 'test'

  # GET /physical_racks
  # GET /physical_racks.json
  def index
    @physical_racks = PhysicalRack.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @physical_racks }
    end
  end

  # GET /physical_racks/1
  # GET /physical_racks/1.json
  def show
    id = params[:id]
    @physical_rack = PhysicalRack.any_of({_id: id}, {name: id.gsub('-', '.')}).first
    @physical_rack.add_missing_hosts # TODO: Does this need to be here???
    @schema = self.schema
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @physical_rack }
      format.csv  {export_csv @physical_rack}
    end
  end

  # GET /physical_racks/new
  # GET /physical_racks/new.json
  def new
    @physical_rack = PhysicalRack.new
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @physical_rack }
    end
  end

  # GET /physical_racks/1/edit
  def edit
    id = params[:id]
    @physical_rack = PhysicalRack.any_of({_id: id}, {name: id.gsub('-', '.')}).first
    @schema = self.schema
  end

  # POST /physical_racks
  # POST /physical_racks.json
  def create
    @physical_rack = PhysicalRack.new(params[:physical_rack])

    respond_to do |format|
      if @physical_rack.save
        format.html { redirect_to @physical_rack, notice: 'Physical rack was successfully created.' }
        format.json { render json: @physical_rack, status: :created, location: @physical_rack }
      else
        format.html { render action: "new" }
        format.json { render json: @physical_rack.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /physical_racks/1
  # PUT /physical_racks/1.json
  def update
    id = params[:id]
    @physical_rack = PhysicalRack.any_of({_id: id}, {name: id.gsub('-', '.')}).first
    @physical_rack.attributes = params[:physical_rack]
    @physical_rack.audits << Audit.new(source: 'controller', action: 'update', admin_user: current_user)
    respond_to do |format|
      if @physical_rack.save
        format.html { redirect_to @physical_rack, notice: 'Physical rack was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render action: "edit" }
        format.json { render json: @physical_rack.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /physical_racks/1
  # DELETE /physical_racks/1.json
  def destroy
    id = params[:id]
    @physical_rack = PhysicalRack.any_of({_id: id}, {name: id.gsub('-', '.')}).first
    @physical_rack.destroy

    respond_to do |format|
      format.html { redirect_to physical_racks_url }
      format.json { head :ok }
    end
  end

  def upload
    id = params[:id]
    @physical_rack = PhysicalRack.any_of({_id: id}, {name: id.gsub('-', '.')}).first

    if request.post? && params[:file].present?
      infile = params[:file].read
      result = import_csv(@physical_rack, infile)
      flash[:info] = "Processed records: #{result[:n]}"
      flash[:notice] = "New hosts: #{result[:insertions]}   " + 
                       "Deleted hosts: #{result[:deletions]}   " + 
                       "Updated hosts: #{result[:updates]}"
      flash[:error] = "There were #{result[:errors]} errors :(" if result[:errors] > 0
    end
    redirect_to @physical_rack
  end

  def schema
    EntitySchema.first(conditions: {name: 'physical_rack'})
  end

  def export_csv(physical_rack)
    # http://www.funonrails.com/2012/01/csv-file-importexport-in-rails-3.html
    filename = "#{@physical_rack.name}_#{@physical_rack.id}_#{Date.today.strftime('%d%b%y')}"
    csv_data = FasterCSV.generate do |csv|
      csv << PhysicalHost.csv_header
      physical_rack.physical_hosts.desc(:u).each do |host|
        csv << render_csv_row(host) unless host.parent_host
        if host.child_hosts.exists?
          host.child_hosts.asc(:n).each do |child|
            csv << render_csv_row(child)
          end
        end
      end
    end
    send_data csv_data,
      :type => 'text/csv; charset=iso-8859-1; header=present',
      :disposition => "attachment; filename=#{filename}.csv"
  end

  def import_csv(physical_rack, csv_string)
    n = 0
    updates = 0
    errors = 0
    deletions = 0
    insertions = 0;
    hosts_ids = []

    # parse and add or update hosts
    CSV.parse(csv_string) do |row|
      n += 1
      # SKIP: header i.e. first row OR blank row
      next if n == 1 or row.join.blank?
      host_id = row[0]
      hosts_ids << host_id unless host_id.nil?
      result = physical_rack.update_host_from_csv(row)
      errors += result[:errors]
      updates += result[:updates]
      insertions += result[:insertions]
    end

    # delete hosts not in the file
    physical_rack.physical_hosts.each do |host|
      unless hosts_ids.include?(host.id.to_s)
        physical_rack.physical_hosts.delete(host)
        deletions += 1
      end
    end
    physical_rack.save!
    return {n: n, updates: updates, insertions: insertions, deletions: deletions, errors: errors}
  end

  def render_csv_row(host)
    pdu1 = host.pdus[0]
    pdu2 = host.pdus[1]
    [host.id, host.u, host.n, host.ob_name, host.name, (host.parent_host.name if host.parent_host), (pdu1.name if pdu1), (pdu1.voltage if pdu1), (pdu1.amps if pdu1), (pdu2.name if pdu2), (pdu2.voltage if pdu2), (pdu2.amps if pdu2)]
  end
end
