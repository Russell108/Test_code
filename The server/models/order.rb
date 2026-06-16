class Order < ApplicationRecord
		
attribute :unnecessary_cart_items, :integer, array: true, default: []
	#====================================   Validations on processing cart   ==================================== 
	# need to 
	# 	validate order on update ie cart
	# validate resources 
		# =>	are downloadable  	done in allocated resource model validates associated in order model
		# =>	have not been acquired  		  	done in allocated resource model    "   "   "   "   "   "   "   "       
		# =>  	are not child of cart package 		done in allocated resource model    "   "   "   "   "   "   "   "  
		# =>  	are not child of  acquired package  done in allocated resource model    "   "   "   "   "   "   "   "  
	# validate package 
		# =>	are admin-cartable & have a bundle  done in allocated package model validates associated in order model
		# =>	have not been acquired    		    done in allocated package model     "   "   "   "   "   "   "   "  
		# =>  	are not child of cart package   
		# =>  	are not child of  acquired package

	# arr.detect {|e| arr.rindex(e) != arr.index(e) } returns nil if no duplicates in array "arr"
	# (i = arr.find_index(x)) && arr.delete_at(i)      remove single instance of "x" from array "arr"
	#====================================   Callbacks   ====================================

	#before_save :set_created_at,   :if => Proc.new { |ao| (ao.status_id_changed? && (ao.status_id==3)) }

 # after_validation :remove_unnecessary_cart_items 

 
	#====================================   Relationships   ====================================
  belongs_to :user
  belongs_to :happening
  
  has_many 	:acquired_packages , :inverse_of =>:order
  has_many 	:acquired_resources , :inverse_of =>:order, autosave: true


  has_many 	:order_items , :inverse_of =>:order, dependent: :destroy
  has_many 	:resources, through: :order_items, source: :resource
  has_many 	:bundles, through: :order_items, source: :bundle
	#====================================   Validations   ==================================== 
	
 
#====================================	validate :validate_cart_not_empty, :on =>:update,	:if =>Proc.new{|order| (order.status_id_changed? && (order.status_id==3))  }
	#====================================   Scopes   ==================================== 

  	scope :by_user,lambda{| user_id| where(user_id: user_id)}
  	scope :by_happening,lambda{| happening_id| where(:happening_id =>happening_id)}
  	scope :by_course,lambda{| course_id| where("happenings.happenable_type = 'Course' and happenings.happenable_id = ?", course_id).joins(:happening)}
  	
 	scope :grouped_cart_user_ids,lambda{| course_id, user_ids| where("orders.status_id = 1 and happenings.happenable_type = 'Course' and happenings.happenable_id = ? and
 										orders.user_id in (?)", course_id,user_ids)
 										.joins(:happening).group("orders.happening_id").pluck("orders.happening_id, ARRAY_AGG(orders.user_id)").to_h}
	#====================================   Validations   ==================================== 

	#====================================   Public Methods   ===============================================
  def remove_order_resource_items_available_through_order_bundle_itme
   
    existing_cart_bundle_ids = self.order_items.where(orderable_type: 'Bundle').collect(&:orderable_id)
    resource_ids_available_form_existing_cart_bundles = Resource.resource_ids_by_bundle_ids(existing_cart_bundle_ids)
  # logger.debug "\n\nexisting_cart_bundle_ids #{existing_cart_bundle_ids}\n\n"
  # logger.debug "\n\nresource_ids_available_form_existing_cart_bundles #{resource_ids_available_form_existing_cart_bundles}\n\n"
    self.order_items.where(orderable_type: 'Resource', orderable_id: resource_ids_available_form_existing_cart_bundles).delete_all
  end
  
  
  
  def self.grouped_cart_user_ids( course_id, user_ids)
     grouped_cart_user_ids = self. where("orders.type = 'Cart' and happenings.happenable_type = 'Course' and happenings.happenable_id = ? and
 										orders.user_id in (?)", course_id,user_ids)
 										.joins(:happening).group("happenings.id").pluck("happenings.id, ARRAY_AGG(ARRAY[orders.user_id, orders.id])")
    two_element_nested_array_to_nested_hash(grouped_cart_user_ids)
  end
     
     
	#====================================   Private Methods   ===============================================
     
  	 private 	
  
	def brick_wall				
		self.errors.add(:base, "brickwall in  order")
		return false
	end	



	def purchasable_format_ids
		centre_id = (happening.type== "Meet") ? happening.happenable.centre_id : happening.happenable_id
		CentreFormat.current_by_centre(centre_id).pluck("format_id")
	end
  

	def set_created_at
		self.created_at =Time.now
	end
 


	def delete_unnecessary_order_items
		# 1		delete all order_packages which are not purchasable have a format which is not admin cartable  or donot belong to order_happening

		OrderPackage.joins(:order,{:package=>:format})
					.where("order_packages.order_id =? and ((packages.purchasable = false )OR(formats.purchasable= false) OR(formats.id NOT In (?)) OR
					(orders.happening_id !=packages.happening_id))", id,purchasable_format_ids).delete_all
			
		# 2		find parent order_packages return child format_ids

	#	child_format_ids=OrderPackage.where("order_packages.order_id =? and ARRAY_LENGTH(formats.format_ids,1) >1", id)\
	#	.joins(:package=>:format)\
	#	.pluck("distinct ON(packages.format_id) formats.format_ids").flatten 


		# if package already acquired delete order_package
		# if package format in child_format_ids delete order_package
		# find above by id then delete
	#	order_package_ids= OrderPackage.where("order_packages.order_id =? and ((orders.user_id = acquired_packages.user_id) OR (packages.format_id in (?)) )",id,child_format_ids )\
	#		.left_outer_joins(:order,{:package=>:acquired_packages}).distinct.pluck("order_packages.id")

		
			
		OrderPackage.where(id:order_package_ids).delete_all

		# 1		delete all order_resources which are not purchasable have a format which is not downloadable   or belong to order happening recordings or are 
		#     are already available in a carted package or allocated package
		acq_package_format_ids =  Package.joins(:acquired_packages).where("acquired_packages.user_id=? and packages.happening_id =? ",user_id,  happening_id).pluck("packages.format_id")
		carted_package_format_ids =  order_packages.joins(:package).pluck("packages.format_id")
		
		

		package_format_ids = (acq_package_format_ids + carted_package_format_ids).uniq
		order_resource_ids=OrderResource.joins(:order,{:resource=>[:acquired_resources,:format, :recording]})
					.where("order_resources.order_id =? and ((resources.purchasable = false )OR(formats.downloadable= false) OR(formats.id  NOT In (?)) OR
					(orders.happening_id !=recordings.happening_id) or (resources.format_id in (?)) OR (orders.user_id = acquired_resources.user_id))", id,purchasable_format_ids,package_format_ids )
		OrderResource.where(id:order_resource_ids).delete_all

		# delete order resources which have already been acquired
		order_resource_ids_2 = OrderResource.where("orders.id = ? and   orders.user_id = acquired_resources.user_id", id)\
		.joins(:order,{:resource=> :acquired_resources}).distinct.pluck("order_resources.id")

	end
  
  
  def self.two_element_nested_array_to_nested_hash(nested_array)
    new_hash={}
    nested_array.to_h.map{|k,v| new_hash[k]=v.to_h}
    return new_hash
  end
  
  
  def remove_unnecessary_cart_items
    logger.debug "\n\n remove_unnecessary_cart_items here #{}\n\n "
    logger.debug "\n\n remove_unnecessary_cart_items here #{self.unnecessary_cart_items.inspect}\n\n "
  #  OrderItem.where(id: self.unnecessary_cart_items).delete_all
  end
  
 

end
