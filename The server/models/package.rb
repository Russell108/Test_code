class Package < ApplicationRecord

#  child default packages must exist
#  cannot delete a child default package if part of parent package
  



#====================================  callbacks    ===============================================

 	before_destroy :verify_destroy#, :brickwall
	before_validation :check_purchasability
	
	#after_validation :set_man_price
 # before_destroy :remove_cart_items
 
 # before_save :remove_cart_items , :if => Proc.new {|package| package.purchasable==false}





  #============================  associations ====================================
	belongs_to	:happening
	#belongs_to	:meet, :class_name=>"Meet",:foreign_key=> :happening_id
	#has_one	:bundle, :inverse_of => :package, :dependent=>:destroy
  has_many :bundle_items , as: :bundleable
  has_many     :bundles , through: :bundle_items
	has_many	:acquired_packages
#	accepts_nested_attributes_for :bundle
	#has_many	:recordings, :foreign_key=> :happening_id, :primary_key=> :happening_id
	belongs_to	:format

  has_many :bundle_items , as: :bundleable
  #============================  validations ====================================
	validates_presence_of :happening
	validates_presence_of :format_id
	validates_uniqueness_of :format_id, scope: :happening_id,
                            :message => "Package already Exists for this event!!"
	#package can only be purchasable if centre_format purchasable & rates available
	# validate this if package purchasable
	#if centre format not purchasable mark package as not purchasable
	
	validate :is_current_active_package , :on => :create, :unless => Proc.new { |p| p.format_id.blank? }
	validate :valid_format , :on => :create, :unless => Proc.new { |p| p.format_id.blank? }
    #============================  scope ====================================

# scope  :purchasable ,->{  where(:purchasable => true)}
# scope  :could_be_made_purchasable, -> {  where("happenings.happening_genre_id = 2").joins(:happening)}

	scope :by_happening_centre,->(centre_id) { 
		 where("happenings.happenable_id = ? AND happenings.happenable_type = ?",centre_id, "Centre").joins(:happening)}

	scope :by_all_areas,->{ where("happenings.happenable_type = ?", "Area").joins(:happening)}
	scope :by_area, lambda{|area_id | where("happenings.happenable_id = ? AND happenings.happenable_type = ?",area_id, "Area").joins(:happening)}
	scope :by_course_centre,->(centre_id) { 
		 where("courses.centre_id = ? AND happenings.happenable_type = ?",centre_id, "Course").joins(happening: :course)}


	scope :by_happening,lambda{|happening_id | where(:happening_id =>happening_id)}
	scope :by_format,lambda{|format_id | where(:format_id =>format_id)}
	
	scope  :acquirable ,->{  where("formats.downloadable is true").joins(:format)}
	scope  :packageable ,->{  where("formats.packageable is true").joins(:format)}


	# following 3 scopes used for acquirerships payne in happenings
	scope :acquireable_plucked_by_happening ,  lambda{|happening_ids |joins(:format)\
			.where("packages.happening_id in (?)", happening_ids )
			.group("packages.happening_id")
			.pluck(Arel.sql("packages.happening_id,array_agg(array[packages.id::text, formats.name::text]) "))
	}
  
	scope :grouped_acquireable_plucked_for_happenings ,  lambda{|happening_ids |joins(:format)\
			.where("packages.happening_id in (?)", happening_ids )
			.group("packages.happening_id")
			.pluck(Arel.sql("packages.happening_id,array_agg(array[packages.id::text, formats.name::text]) ")).to_h
	}

  scope  :happening_acquired_packages_by_user, lambda{|user_ids, happening_ids | joins(:acquired_packages, :format)
        .where("acquired_packages.user_id in (?) and packages.happening_id in (?)", user_ids,happening_ids )\
        .group("acquired_packages.user_id")\
        .pluck(Arel.sql("acquired_packages.user_id, array_agg(array[acquired_packages.package_id::text, acquired_packages.id::text, formats.name::text , acquired_packages.order_id::text] )"))
  }

	scope  :plucked_gratis_acquired_packages_for_user_by_happening,   lambda{|user_id, happening_ids |joins(:format, :acquired_packages)
			.group("packages.happening_id")\
			.where("acquired_packages.user_id =? and packages.happening_id in (?) and acquired_packages.order_id is  NULL", user_id, happening_ids)
			.pluck(Arel.sql("packages.happening_id, array_agg(array[ acquired_packages.id::text, formats.name::text])")).to_h
	} 
 
	scope  :plucked_acquired_packages_for_user_by_happening,   lambda{|user_id, happening_ids |joins(:format, :acquired_packages)
			.group("packages.happening_id")\
			.where("acquired_packages.user_id =? and packages.happening_id in (?) ", user_id, happening_ids)
			.pluck(Arel.sql("packages.happening_id, array_agg(array[ acquired_packages.id::text, formats.name::text])")).to_h
	} 
  
  scope  :carted_bundled_package_formats_by_user ,   lambda{|  user_ids,happening_id |joins(:format, {bundle_items: {bundle: {order_items: :order}}})\
  .where("bundle_items.bundleable_type= ? and bundles.happening_id = ? and orders.type = ? and orders.user_id in (?)", 'Package', happening_id,'Cart', user_ids)\
  .group("orders.user_id")\
  .pluck(Arel.sql("orders.user_id, array_agg(formats.name)"))}
	#====================================   Public Class Methods   ===============================================


	#============================  public methods ====================================
	
	def format_name
		("&nbsp;" + format.name + "&nbsp;&nbsp;").html_safe
	end
  
	def check_purchasability

		unless self.purchasable
				self.bundle_items.destroy unless self.bundle_items.nil?
		end

		
	end
  
   #============================  private methods ====================================


   
	private


    def valid_format
    	happening.centre.centre_formats
     
    end
 
	def verify_destroy
		 allow_destroy = true
		 unless acquired_packages.where.not("acquired_packages.order_id =?", nil).empty?
		   errors.add( :base,"Has been purchased.") 
		   allow_destroy = false
		 end
    #unless bundle_items.empty?
    #    errors.add(:package, "#{format.name}:  is part of a Bundle") 
    #   allow_destroy= false
    #end
    (throw :abort )unless allow_destroy
	end


 # Package.joins(:acquired_packages).where("packages.format_id=?", 1).where("acquired_packages.order_id=?", nil).size
 #  Package.joins(:acquired_packages).where("packages.format_id=?", 1).where("acquired_packages.order_id> ?", 0).size
#	def centre_format
#		
#		(return nil)unless (centre = self.happening.centre)
#		
#		(return nil)unless( centre_format =  centre.centre_formats.find_by_format_id(format_id) )
#		return centre_format
#	end



  
    
    def is_current_active_package
    	
    	 current_creatable_format_ids =  happening.current_creatable_formats.ids
    	unless(format.packageable && (current_creatable_format_ids.include? format_id ))
    	 	 self.errors.add(:format_id, " #{self.format.name rescue nil} invalid for  Packages")
    	 	 return false
		end
    end
    
    def is_a_number?(s)
      s.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) 
     
    end
    
	def self.nested_array_to_hash(nested_array)
	    h = Hash.new{ |h,k| h[k]=[] }
	    nested_array.each{ |k,v| h[k] << v.flatten }
	   h.each { |k, v| h[k] = v.flatten.uniq } 
	   return h
	end 
end
