class Cart < Order
  
  
  around_save :process_order , :if => Proc.new { |cart|  cart.type == 'ProcessedOrder'} 
  #====================================   validations   ====================================

	validates_uniqueness_of :user_id, scope: [:happening_id], message: "Cart already exists"
  validate :cart_not_empty?, :if => Proc.new { |cart|  cart.type == 'ProcessedOrder'}
  validate :check_validity_of_order_items, on: :update
  validate :ensure_no_availability_through_order_bundle, on: :update
  validate :check_order_items_not_already_purchased,  on: :update
  validate :resource_order_items_not_available_through_purchased_bundle,  on: :update
  validate :customer_valid_for_admin_purchase , :if => Proc.new { |cart|  cart.happening} 
  #validate :brickwall
 
  #====================================   public methods   ====================================
  


  
  def add_acquisitions_for_user
    self.order_items.each do |order_item|
        case order_item.orderable_type
          when 'Resource'
            acquired_resource =  user.acquired_resources.find_or_initialize_by(resource_id: order_item.orderable_id)
            acquired_resource.order_id = id
            acquired_resource.save
          when "Bundle"
              self.add_acquisitions_for_user_ordered_bundle(order_item)
        end
    end
  end
  
  def add_acquisitions_for_user_ordered_bundle(order_item)
    order_item.orderable.bundle_items.each do |bundle_item|
      case bundle_item.bundleable_type
        when 'Resource'
          acquired_resource =  user.acquired_resources.find_or_initialize_by(resource_id: bundle_item.bundleable_id)
          acquired_resource.order_id = id
          acquired_resource.save
        when 'Package'
          acquired_package =  user.acquired_packages.find_or_initialize_by(package_id: bundle_item.bundleable_id)
          acquired_package.order_id = id
          acquired_package.save
        end
    end
  end
  
  
  
  def self.create_cart_for_valid_members(happening)
    created_carts =0
    error_messages =[]
    memberships = happening.memberships.where(active:true, users: {archived:false}).includes(:user)
    logger.debug "\n\ncreate_cart_for_valid_members #{memberships.collect(&:user_id)} \n\n"
     memberships.each do |membership|
       cart = Cart.find_or_initialize_by(happening_id: happening.id, user_id: membership.user_id)
      if cart.save
        created_carts +=1
      else
         error_messages <<  (cart.user.forename + " " + cart.user.surname + ": " +  cart.errors.full_messages.join(", ") + "<BR>" )
      end
    end
    return [created_carts,error_messages]
  end
  
  
  def  self.create_cart_for_valid_members_and_add_bundle(happening, bundle_id )
    
    created_carts =0
    error_messages =[]
    users_already_purchased_bundle = Order.joins(:order_items).where("orderable_type =? and  orderable_id = ?", "Bundle",bundle_id ).collect(&:user_id)
    user_ids_for_new_cart =  happening.memberships.where(active:true).where.not(user_id: users_already_purchased_bundle).collect(&:user_id)
    logger.debug "\n\n happening: #{happening.id}"
    logger.debug "\n\n debug: \n#{users_already_purchased_bundle} \n user_ids_for_new_cart #{user_ids_for_new_cart}\n\n"
    user_ids_for_new_cart.each do |user_id| 
      cart = Cart.find_or_initialize_by(happening_id: happening.id, user_id: user_id)
      cart.order_items.build(orderable_type: 'Bundle', orderable_id: bundle_id)
     if cart.save
       created_carts +=1
       logger.debug("\n\n success\n\n")
     else
        error_messages <<  (cart.user.forename + " " + cart.user.surname + ": " +  cart.errors.full_messages.join(", ") + "<BR>" )
     end
     
    end
    
     return [created_carts,error_messages]
  end
  #====================================   private methods   ====================================
  private
  
  #def brickwall
	#	self.errors.add(:base, " no carty brick_wall!")
	#	return false
  #end
  

  
  def cart_not_empty?
     
  	if order_items.empty?
  		self.errors.add(:order_items, "Basket is empty!!")
  		return false
  	end
  end
  
  def process_order
    yield
    self.add_acquisitions_for_user
  end
  
  def customer_valid_for_admin_purchase
    
    eligible_customer = true
    message= ""
    result= self.user.validate_as_admin_customer(happening)
    eligible_customer = result[0]
    message= result[1]
    self.errors.add(:user, message) unless eligible_customer
    
    return eligible_customer
  end
  
  
  def check_validity_of_order_items
    items_valid =true
    valid_resources = Resource.where(id: resource_ids, purchasable:true).size
    if(valid_resources != resources.size)
       items_valid = false
        message = "one or more items invalid"
    end
    self.errors.add(:order_items, message) unless items_valid
	  return items_valid
  end
 
 
  def ensure_no_availability_through_order_bundle 
    resource_ids= self.resources.ids
    format_ids= self.resources.collect(&:format_id).uniq
   # puts"\nin the model resource_ids #{resource_ids}"
   # puts "\nformat_ids in model #{format_ids}\n"
    not_in_carted_bundle = true
    #check bundle packages
    
     if (( Bundle.joins(:packages, {order_items: :order})\
     .where(happening_id: happening.id).where("orders.type = ? and packages.format_id in(?) and orders.user_id = ?",'Cart', format_ids, user_id).any?\
     ) or ( Bundle.joins(:resources, {order_items: :order})\
     .where(happening_id: happening.id).where("orders.type = ? and resources.id in (?) and orders.user_id = ?",'Cart', resource_ids, user_id).any?
     ))
        message = "One or more resources available through carted bundle"
        not_in_carted_bundle = false
     end
     
     
    self.errors.add(:order_items, message) unless not_in_carted_bundle
	  return not_in_carted_bundle
  end
  
 
  def check_order_items_not_already_purchased
    not_yet_purchased = true
    if OrderItem.joins(:order).where("orders.type =? and order_items.orderable_type =? and order_items.orderable_id in(?) and orders.user_id =?",\
       'ProcessedOrder', 'Resource', resource_ids, user_id).any?
       message = "One or more items already purchased"
       not_yet_purchased = false
    end
    if OrderItem.joins(:order).where("orders.type =? and order_items.orderable_type =? and order_items.orderable_id in(?) and orders.user_id =?",\
       'ProcessedOrder', 'Bundle', bundles.ids, user_id).any?
       message = "One or more items already purchased"
       not_yet_purchased = false
    end
    self.errors.add(:order_items, message) unless not_yet_purchased
	  return not_yet_purchased
  end

  def resource_order_items_not_available_through_purchased_bundle
    resource_ids= resources.ids
    format_ids= resources.collect(&:format_id).uniq
      not_available = true
      if AcquiredPackage.joins(:package).where("packages.happening_id =? and acquired_packages.user_id =? and packages.format_id in (?)",\
         happening_id, user_id, format_ids).where.not(order_id: nil).any?
         message = "One or more items available through bundle purchase"
         not_available = false
      end 
      if AcquiredResource.where(user_id: user_id ,resource_id:resource_ids ).where.not(order_id: nil).any?
        message = "One or more items available through bundle purchase"
        not_available = false
     end 
      
      self.errors.add(:order_items, message) unless not_available
  	  return not_available
  end

end
