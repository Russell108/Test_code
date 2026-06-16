class ProcessedOrder < Order
  
  before_validation :rationalize_order_items
  
 # after_save :remove_acquisitions , :if => Proc.new { |cart|  cart.type == 'RefundedOrder'} 
  
  around_destroy :remove_acquisitions , :if => Proc.new { |order|  order.type == 'ProcessedOrder'}
#====================================   Relationships   ====================================
  
  has_many :order_items, foreign_key: "order_id"
  
  #====================================   validations   ====================================
  
 
  
  
  #====================================   public methods   ====================================
  
  

     
  def add_acquisitions_to_user_account
    
    self.order_items.each do |order_item|
       logger.debug "\n\n hello world order_item #{order_item} \n\n"
      case order_item.orderable_type 
        when "Resource"
          AcquiredResource.create_order_resource(order_item, self.user_id)
        when "Bundle"
          
        end
       
    end
  end

  
  private
  
  def rationalize_order_items
    self.remove_order_resource_items_available_through_order_bundle_itme
  end   
  
  
  def remove_acquisitions
    order_id = id
      yield
     AcquiredPackage.where(order: order_id).delete_all
     AcquiredResource.where(order:order_id).delete_all
 
  end


end
