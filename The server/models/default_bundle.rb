class DefaultBundle < ApplicationRecord
  
  
  belongs_to :course
  
  has_many :default_items , as: :defaultable, dependent: :destroy
  has_many :default_packages , as: :defaultable
  has_many :default_package_formats , through: :default_packages, source: :format
  
  
  validates_presence_of   :course, :name 
  validates_numericality_of :price, { greater_than_or_equal_to: 0, message: "must be greater than or equal to £0-00" }
  validates_uniqueness_of :name, scope: :course, allow_blank: true
  validate :default_packages_valid
  validate :existance_of_packages
  
  scope :by_course_for_new_mmet_form,lambda{|course_id | where(course_id: course_id)
    .collect{|db|[(db.name + " £" + db.price.to_s + ' with packages: ' + db.default_package_formats.collect(&:name).join(', ')), db.id]}
  	                                               }
  
  
	def price
 		man_penny_price / 100.0
 	end

 	def price=(_price)
 		 
 		#self.penny_price  = Price.new(amount: (_price.to_d * 100)).rounded_price
 		self.man_penny_price  =  _price.to_d * 100
 	end
  
  private
  
  def default_packages_valid
      format_ids = Format.current_by_centre(course.centre_id).is_packageable.ids
      unless((default_package_format_ids - format_ids).empty?)
          errors.add(:default_package_format_ids, "Some formats not available for this centre") 
  
      end
  end
  
  def existance_of_packages
    course_package_format_ids = course.default_packages.collect(&:format_id)
    missing = default_package_format_ids - course_package_format_ids
    unless( missing.empty?)
      errors.add(:default_package_format_ids,"The following default course packages are missing: " + Format.where(id: missing).pluck(:name).join(', '))  
    end
  end
  

end
