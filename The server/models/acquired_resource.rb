class AcquiredResource < ApplicationRecord
	strip_attributes
  
 	#====================================   Call backs   ==================================== 
	before_destroy :verify_destroy 
  after_save     :remove_cart_resource , :if => Proc.new { |ar|  ar.order_id.blank? } 
	#====================================   Validations   ==================================== 
	validates_presence_of :user_id, :resource_id
	validates_uniqueness_of :resource_id, scope: :user_id, message: "user has already acquired this one"
 	validate :acquirability
 	validate :check_4_acquired_package , :if => Proc.new { |ar|  ar.order_id.blank? } 
  #validate :brickwall
	#====================================   Relationships   ==================================== 

	belongs_to :resource
	belongs_to :user
	belongs_to :order, optional: true

	#====================================   Scopes   ==================================== 

	scope :by_recording,lambda{| recording_id| 
  		where(resources:{:recording_id =>recording_id}).joins(:resource)}
  	scope :by_user,lambda{| user_id| where(:user_id =>user_id)}
  	scope :by_order,lambda{| order_id| where(:order_id =>order_id)}
  	scope :by_resource,lambda{| resource_id| where(:resource_id =>resource_id)}
  	scope :by_happening,lambda{| happening_id| 
  		where("recordings.happening_id =?",  happening_id).joins(:resource=> :recording)}	
  	scope :by_format,lambda{| format_id| 
  		where(resources:{:format_id =>format_id}).joins(:resource)}
  	
  	scope :gratis , ->{  where(:order_id=> nil)}
  	scope :purchased , ->{  where.not(:order_id=> nil)}
  	

#	# used in acquisitions controllers
	scope :gratis_acquired_4_user ,  lambda{|user_id, happening_ids |joins({:resource=>[:recording, :format]})
			.group("recordings.happening_id ,recordings.number")\
			.where("acquired_resources.user_id =? and recordings.happening_id IN (?) and acquired_resources.order_id is NULL", user_id, happening_ids)
			.pluck("recordings.happening_id ,recordings.number,ARRAY_AGG(ARRAY[ acquired_resources.id::text,formats.name ])")
	}


  def self.create_order_resource(order_item, user_id)
    acquired_resource= AcquiredResource.find_or_initialize_by(user_id: user_id, resource_id: order_item.orderable_id)
    acquired_resource.order_id = order_item.order_id
    acquired_resource.save
   
  end

  def self.happening_acquired_resources_group_by_user(happening_id, user_ids)
    acquired_resources= AcquiredResource
                        .joins(resource: :recording)
                        .where("recordings.happening_id = ? and acquired_resources.user_id in (?)", happening_id, user_ids)
                        .group(["acquired_resources.user_id"])\
                        .pluck(Arel.sql('acquired_resources.user_id, array_agg(ARRAY[acquired_resources.resource_id, acquired_resources.order_id])'))
    two_element_nested_array_to_nested_hash(acquired_resources)
  end
  
 

 	#====================================   Private Methods   ===============================================

  private
 	def self.per_page
		return 5
  	end

  	def self.per_resource_page
		return 18
  	end
	private

	def acquirability
		
		unless resource.format.downloadable
			self.errors.add(:format, " is not downloadable")
      		throw(:abort) 
      	end
      
      	
	end

	def check_4_acquired_package
		if (resource.recording.happening.acquired_packages.by_format(resource.format_id).by_user(user_id).any?)
			self.errors.add(:user, " already has access to #{self.resource.format.name} in acquired package")
      		throw(:abort)
      	end
	end

  def remove_cart_resource
    # check if 
    resource.order_items.joins(:order).where('orders.user_id = ?', user_id).delete_all
  end

  def self.two_element_nested_array_to_nested_hash(nested_array)
    new_hash={}
    nested_array.to_h.map{|k,v| new_hash[k]=v.to_h}
    return new_hash
  end

	def verify_destroy
		allow_destroy=   true
		if order_id         
		    errors.add("base", "Has Been Purchased.")
		    allow_destroy=   false
		end
	#	errors.add("base", "brick wall.")
	#	allow_destroy =   false
	#	(throw :abort )unless allow_destroy
	end
  def brickwall
		self.errors.add(:base, "brick_wall!")
		return false
  end
  
end
