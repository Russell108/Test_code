class Bundle < ApplicationRecord
  strip_attributes :collapse_spaces => true
  attribute :format_ids, :integer, array: true
  
	#====================================   callbacks   ===============================================
	
#	before_save :write_to_log
#	before_save	:set_cumulative_penny_price
  around_save :create_bundle_items , if: Proc.new { |bundle| (bundle.new_record? and bundle.format_ids and !bundle.format_ids.empty?) } 
	
	#============================  associations ====================================
	
#	belongs_to   :package,  optional: true
  belongs_to  :happening
  has_many     :bundle_items, dependent: :destroy
  has_many     :bundle_packages, -> { where("bundleable_type=?", 'Package')}, class_name: "BundleItem", inverse_of: :bundle
  has_many     :bundle_resources, -> { where("bundleable_type=?", 'Resource')}, class_name: "BundleItem", inverse_of: :bundle
  
  has_many     :packages , through: :bundle_packages, source: :package
  has_many     :resources , through: :bundle_resources, source: :resource
  has_many    :order_items, as: :orderable
	#delegate :happening, :to => :package, :allow_nil => true
   accepts_nested_attributes_for :bundle_items
  
    

	#====================================   validations   ===============================================
		#validate :centre_price_availability
	#	validate :brick_wall
    validates_presence_of :name
		validates_uniqueness_of :name, scope: :happening
	 
#		validate :centre_price_availability
	#====================================   scopes   ===============================================

	scope :by_format,lambda{|format_id | where(:packages=> {:format_id =>format_id}).joins(:package)}




  

	#============================  public methods ====================================

	def price
 		penny_price / 100.0
 	end

 	def price=(_price)
 		 
 		#self.penny_price  = Price.new(amount: (_price.to_d * 100)).rounded_price
 		self.penny_price  =  _price.to_d * 100
 	end


	def brick_wall
		errors.add(:base,"Bundless & co Brick Wall")
    throw :abort
	end


	#============================  private methods ====================================

  def create_bundle_items
    yield
    format_ids.delete_if(&:blank?).each do |format_id|
      package = self.happening.packages.find_or_create_by(format_id: format_id)
      logger.debug "\n\n package #{package.inspect}\n\n"
      self.bundle_items.create(bundleable: package
       ) 
    end
  end
  
 	def centre_price_availability
    unless centre_format
    	errors.add(:centre_id,"centre format not defined")
    	return  false
    end
  end

	
end
