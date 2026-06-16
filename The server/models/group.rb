class Group < ApplicationRecord
  include GroupImporting
   attribute :delete_import, :boolean,  default: false
   attribute :import_csv, :boolean,  default: false
   attribute :clone_group, :integer
   attribute :remove_emails, :string
   
 # require 'csv'
  
  has_one_attached :import, service: :linode
  strip_attributes :collapse_spaces => true
#====================================   callbacks   ===============================================
    
    before_validation :titleize_name ,unless:  Proc.new{ |group|  group.title.blank?} 
    before_validation :remove_import,  if:  Proc.new{ |group|  group.delete_import == true}
    
   
    has_many :attached_groups, dependent: :destroy
    has_many :group_memberships, dependent: :destroy
    has_many :users, through: :group_memberships
    belongs_to :user

#====================================   validations   ===============================================

    validates_length_of :title, minimum: 3
    validates_presence_of :title
    validates_uniqueness_of :title
#====================================   Private Methods   ===============================================


  def process_csv_for_edit
    csv = process_csv
   users =[]
    csv.each do |row|
     user = User.new
     user.forename = row["First Name"]
     user.surname = row['Last Name']
      user.email = row['Email']
     users << user
    end
   # logger.debug("\n\n csv size #{csv.size} \n")
   # imported_emails = users.collect(&:email)
  #
   #
   #</tt> found_users = User.where(email: imported_emails)
    
    return users
  end
  
 
  def check_in_import
    
    csv = process_csv    
  
    
    remove_emails = self.remove_emails.split(",") rescue []
    # build  users
    users =[]
    csv_emails =[]
    imported_emails =[]
    acquired_groups =[]
    csv.each do |row|
      csv_emails <<row['Email']
    #  unless (row['Email'].blank? or remove_emails.include?(row['Email']))
    unless  remove_emails.include?(row['Email'])
        user = User.find_or_initialize_by(email: row['Email']) do |user|
          user.forename = row["First Name"]
          user.surname = row['Last Name']
         
        end
          users << user unless user.persisted?
          imported_emails <<user.email 
          user.valid?
         
      end
    end
     # create users
    user_import_result = User.import( users ,validate: true, validate_uniqueness: true)
     new_memberships =[]
     User.where(email: imported_emails).each do |user|
         new_memberships << GroupMembership.new(user_id: user.id, group_id: self.id)
     end
   
     membership_import_result =GroupMembership.import new_memberships ,validate: true, validate_uniqueness: true
     
     #create group memberships
     group_memberships= GroupMembership.joins(:user).where("group_memberships.group_id =? and users.email in (?)", self.id, csv_emails).uniq
     import.purge if (csv.size == acquired_groups.size)
    
    return results_array_from_import_with_pre_imports(new_memberships.size, membership_import_result, user_import_result,
            " or more people not imported due to one or more of the following reasons")
  end
  
  def clone_group_members
    group_memberships= []
    user_ids = Group.find(clone_group).user_ids
    user_ids.each do |user_id|
      group_membership = GroupMembership.new(group_id: id, user_id: user_id )
      group_memberships << group_membership 
    end
    import_result=  GroupMembership.import group_memberships ,validate: true, validate_uniqueness: true
    return results_array_from_import(users.size, import_result,  "  users were not added for one or more of the following reasons")
    
  end
  
  
  def process_group_membership_application(happening, mbr_type_id)
    flash_notice= flash_error = ""
     group_user_ids_where_membership_exists = self.users.joins(:memberships)
     .where("memberships.joinable_type =? and memberships.joinable_id =?", 'Happening', happening.id).ids
     
     group_user_with_plucked_fullname_grouped_by_existing_membership_type = self.users.grouped_and_plucked_members_by_joinable('Happening', happening.id).to_h
     group_users_requiring_membership =  self.users.where.not(id: group_user_ids_where_membership_exists)
     
     results_array =  Membership.manage_by_team_for_joinable( happening, group_users_requiring_membership, mbr_type_id)
     
     flash_notice ="#{results_array[0]} #{"membership".pluralize(results_array[0]) } created<BR><BR>"
     flash_notice << "<u class='text-dark'>Active memberships already existing</u><BR>" 
     
     add_existing_memberships_2_flash(group_user_with_plucked_fullname_grouped_by_existing_membership_type ,flash_notice ,flash_error)
        
     flash_error << results_array[1].join("<BR>").html_safe
     return [flash_notice, flash_error]
  end
  
  
  
	private
  
  def add_existing_memberships_2_flash(memberships ,flash_notice ,flash_error)
    memberships.each do |item|
      if item[0]== 'Lapsed'
        flash_error << "<u class='text-dark'>#{item[1].size} #{"Lapsed Membership".pluralize(item[1].size)} already existing</u><BR>"
        flash_error << item[1].join(', ') + '<BR>'
      else
       flash_notice << item[0] + ' ' + item[1].size.to_s + '<BR>'
      end
    end
    return [flash_notice, flash_error]
  end
  
  
  def process_csv
    csv_text = self.import.download
    csv_text = csv_text.force_encoding('utf-8')
   csv_text.sub!("\xEF\xBB\xBF".force_encoding('UTF-8'), '')
    
    return CSV.parse(csv_text, encoding: 'utf-8',  :headers => true, :liberal_parsing => true)
  end


  
  def titleize_name
    self.title = self.title.titleize
  end
  
  
  def remove_import
    
    import.purge
  end
  

 
  def results_array_from_import_with_pre_imports(user_group_size, import_result, *pre_import_results, start_message)
    import_size =import_result.ids.size
    errors=["<u class='text-dark'>#{user_group_size- import_size} #{start_message}:</u><BR>"]
    pre_import_results.each do |import_result|
      import_result.failed_instances.each do |instance| 
        instance.errors.full_messages.each do |message|
          errors |= [message] unless(message =="Cart already exists")
        end
      end
      
    end
    import_result.failed_instances.each do |instance| 
      instance.errors.full_messages.each do |message|
        errors |= [message] unless(message =="Cart already exists")
      end
    end
    errors ="" if (errors.size ==1)
    
    return[import_result.ids.size, errors]
  end
  

 
end
