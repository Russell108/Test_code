class AcquiredPackage < ApplicationRecord
	 
	 strip_attributes
  
 	#====================================   Call backs   ==================================== 
	before_destroy :verify_destroy 
	after_save		:remove_contained_acquired_resources	#unless acquired resource is an order item
  after_save     :remove_cart_resource , :if => Proc.new { |ap|  ap.order_id.blank? } 
	#====================================   Validations   ==================================== 
	validates_presence_of :user_id, :package_id
	validates_uniqueness_of :package_id, scope: :user_id, message: "already acquired"
 	validate :acquirability, :unless => Proc.new{ |u|  u.package.blank?  }
  #validate :brickwall
	#====================================   Relationships   ==================================== 

	belongs_to :package
	belongs_to :user
	belongs_to :order , optional: true

	#====================================   Scopes   ==================================== 

	scope :by_happening,lambda{| happening_id| 
  		where(packages:{:happening_id =>happening_id}).joins(:package)}
  	scope :by_user,lambda{| user_id| where(:user_id =>user_id)}
  	scope :by_format,lambda{| format_id| 
  		where(packages:{:format_id =>format_id}).joins(:package)}
  	scope :gratis , ->{  where(:order_id=> nil)}
  	scope :purchased , ->{  where.not(:order_id=> nil)}
  	scope :by_order,lambda{| order_id| where(:order_id =>order_id)}
    
 	#====================================   Public Methods   ===============================================

  
 	#====================================   Private Methods   ===============================================
  
 	
	private

	def acquirability
		unless Format.is_packageable.where(id: package.format_id)
			self.errors.add(:format, " is not acquirable")
      		 throw(:abort)
      	end
	end

	def remove_contained_acquired_resources
		#on creating an acquired package remove the users acquired resources he has access to
		# tthrough the package unless its an order

		AcquiredResource.by_user(user_id).by_happening(package.happening_id).by_format(package.format_id).each  do |resource|
			resource.delete unless resource.order_id
		end
	end
  
 
  
  def remove_cart_resource
    # find happening acrt resources for user with same format id
     OrderItem.by_happening(package.happening_id).by_user(user_id)
    .joins(:resource)
    .where("orders.type = ? and orderable_type =? and resources.format_id =?",'Cart', 'Resource', package.format_id).delete_all
  end

	def verify_destroy
		allow_destroy=   true
		if order_id         
		    errors.add("base", "Has Been Purchased.")
		    allow_destroy=   false
		end
		#errors.add("base", "brick wall.")
		#allow_destroy =   false
		(throw :abort )unless allow_destroy
	end

  def self.two_element_nested_array_to_nested_hash(nested_array)
    new_hash={}
    nested_array.to_h.map{|k,v| new_hash[k]=v.to_h}
    return new_hash
  end
  
  def brickwall
		self.errors.add(:base, "brick_wall!")
		return false
  end
end
