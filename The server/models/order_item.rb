class OrderItem < ApplicationRecord

  after_save    :rationalise_order_resource_items, :if => Proc.new { |order_item| order_item.orderable_type == 'Bundle'} 

  belongs_to  :order, optional: :true
  belongs_to  :orderable, polymorphic: true
  belongs_to :resource, foreign_key: :orderable_id, class_name: 'Resource', optional: :true
  belongs_to :bundle, foreign_key: :orderable_id, class_name: 'Bundle', optional: :true
  
  #############################    validations.  ##########################
  validates_presence_of :order, message: "user does not have cart"
  validates_uniqueness_of :order, scope: [:orderable], message: "already includes this item",  :if => Proc.new { |order_item| order_item.order }  
  validate :customer_valid_for_admin_purchase,  :if => Proc.new { |order_item| order_item.order } 
  validate :orderable_resource_is_purchasable,  :if => Proc.new { |order_item| order_item.orderable && (order_item.orderable_type== 'Resource' )} 
  validate :orderable_not_already_purchased,  :if => Proc.new { |order_item| order_item.order }  
  validate :orderable_not_already_acquired,  :if => Proc.new { |order_item| order_item.orderable && (order_item.orderable_type== 'Resource' ) } 
  validate :ensure_no_availability_through_purchased_package, 
  :if => Proc.new { |order_item| order_item.order && order_item.orderable && (order_item.orderable_type== 'Resource' ) } 
  validate :ensure_no_availability_through_order_bundle,
  :if => Proc.new { |order_item| order_item.order && order_item.orderable_type == 'Resource'} 

  ############################    scopes.  ##########################

	scope :by_user,lambda{| user_id| 
		where("orders.user_id =?",  user_id).joins(:order)
  }	
  
	scope :by_happening,lambda{| happening_id| 
		where("orders.happening_id =?",  happening_id).joins(:order)
  }	
  
  scope :by_type,lambda{| orderable_type| 
  	where(orderable_type:  orderable_type)
  }  
   
  scope :purchased,lambda{
  	where("orders.type=?", "ProcessedOrder")
   .joins(:order)  
  }    
 
  scope :purchased_order_items_plucked_and_grouped_by_user,  lambda{|happening_id ,user_ids, orderable_type|\
    joins(:order).where('orders.type = ? and orders.user_id in (?) and orders.happening_id=? and order_items.orderable_type = ?',
    'ProcessedOrder', user_ids, happening_id,orderable_type )\
    .group(["orders.user_id"])\
    .pluck(Arel.sql('orders.user_id, array_agg(order_items.orderable_id)'))
  }
  
  scope :plucked_resource_formats_by_recording, ->{
    joins(resource: [:format, :recording])
    .group('recordings.number, recordings.title')
    .order('recordings.number')
    .pluck(Arel.sql("recordings.number, recordings.title, string_agg(formats.name, ', ')"))
  }
  
  
 
  ############################    public methods.  ##########################
 
  def self.bundle_cart_items_plucked_and_grouped_by_user(happening_id, user_ids)
    bundle_cart_items = self.joins(:order).where('orders.type = ? and orders.user_id in (?) and orders.happening_id=? and order_items.orderable_type = ?',
    "Cart",user_ids,  happening_id,'Bundle' )\
    .group(["orders.user_id"])\
    .pluck(Arel.sql('orders.user_id, array_agg(ARRAY[ order_items.orderable_id, order_items.id] )'))
    two_element_nested_array_to_nested_hash(bundle_cart_items)
  end
  
  def self.ordered_bundles_by_user_by_order_ids_grouped_by_order( user_id, order_ids)
    self.where("order_items.orderable_type = ? and orders.user_id =? and orders.id in (?)","Bundle", user_id, order_ids)
        .joins(:bundle, :order)
        .group("orders.id","order_items.orderable_type")\
        .pluck(Arel.sql('orders.id, array_agg( bundles.name )')).to_h
        
  end
  
  def self.ordered_resources_by_user_by_order_ids_grouped_by_order(user_id, order_ids)
    self.where("order_items.orderable_type = ? and orders.user_id =? and orders.id in (?)",'Resource', user_id, order_ids)
        .joins({resource: [:recording, :format]}, :order)
        .group("orders.id","order_items.orderable_type")\
        .pluck(Arel.sql('orders.id, array_agg(ARRAY[recordings.number::text, formats.name::text] )')).to_h
        
  end
  
  private
  
  def self.two_element_nested_array_to_nested_hash(nested_array)
    new_hash={}
    nested_array.to_h.map{|k,v| new_hash[k]=v.to_h}
    return new_hash
  end
  
  def ensure_no_availability_through_order_bundle
    logger.debug "\n\nensure_no_availability_through_order_bundle\n\n"
     already_included= order.bundles.left_outer_joins(bundle_items: [:package, :resource])
    .where("(bundle_items.bundleable_type=? and bundle_items.bundleable_id=?) OR
    (bundle_items.bundleable_type=? and packages.format_id=?)", 'Resource', orderable_id, 'Package', orderable.format_id).any?
   
    if (already_included)
		  self.errors.add(:orderable, "available through already carted bundle")
		  return false
    end
  end
  

  
  def rationalise_order_resource_items
    order.remove_order_resource_items_available_through_order_bundle_itme
    
  end
  
  def orderable_resource_is_purchasable
    purchasable_resource = true
    unless orderable.purchasable
     purchasable_resource = false
     message = "resource not purchasable".html_safe
   end
    self.errors.add(:orderable, message) unless purchasable_resource
	  return purchasable_resource
  end
  
  
  def customer_valid_for_admin_purchase
    
    eligible_customer = true
    message= ""
    result= order.user.validate_as_admin_customer(order.happening)
    eligible_customer = result[0]
    message= result[1]
    self.errors.add(:user, message) unless eligible_customer
    return eligible_customer
  end
  
  def orderable_not_already_purchased
    purchasable = true
    if(  OrderItem.where(orderable_type: orderable_type, orderable_id: orderable_id).joins(:order)
          .where("orders.type =? and orders.user_id =?", "ProcessedOrder",order.user_id).exists?
          )
        message = "item already putchased".html_safe
       purchasable = false
     end
    self.errors.add(:orderable, message) unless purchasable
	  return purchasable
  end
  
  def orderable_not_already_acquired
    purchasable = true
    logger.debug "\n\norderable_not_already_acquired\n\n"
    if AcquiredResource.where(user_id:order.user_id,resource_id: orderable_id ).any?
      message = "item already acquired".html_safe
      purchasable = false
    end
    self.errors.add(:orderable, message) unless purchasable
	  return purchasable
  end
  
  def ensure_no_availability_through_purchased_package
    purchasable =true
   if AcquiredPackage.joins(:package)
     .where(user_id: order.user_id)
     .where("packages.format_id =? and packages.happening_id = ?", orderable.format_id, order.happening_id)
    .where.not(order_id: nil).any?
      purchasable = false
      message = "resource available through purchased package".html_safe
    end
    self.errors.add(:orderable, message) unless purchasable
     return purchasable
  end
  
  ############################    private methods.  ##########################
  private
  

end
