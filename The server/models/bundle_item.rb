class BundleItem < ApplicationRecord
  
  around_save    :rationalise_bundled_resources, :if => Proc.new { |bundle_item| bundle_item.bundleable_type == 'Package'} 
 # before_destroy :verify_destroy
 # validate        :brickwall
  belongs_to :bundleable, polymorphic: true
  belongs_to :bundle
  belongs_to :resource, foreign_key: :bundleable_id, class_name: 'Resource', optional: :true
  belongs_to :package, foreign_key: :bundleable_id, class_name: 'Package', optional: :true
  #	belongs_to :course,  :class_name => "Course",:foreign_key => "happenable_id" 
  
  validates_uniqueness_of :bundle_id, scope: [:bundleable_id, :bundleable_type], message: "already includes this item"
  
  validate :no_availability_through_bundled_package, :if => Proc.new { |bundle_item| bundle_item.bundleable_type == 'Resource'} 
  #====================================   scopes   ===============================================
  scope :plucked_and_hashed_by_bundleable_type, lambda{|bundleable_type | where(bundleable_type: bundleable_type).pluck('bundleable_id, id').to_h}
  scope :by_bundleable_type, lambda{|bundleable_type | where(bundleable_type: bundleable_type)}
  
  
  
  
  def self.bundle_resources_hashed_and_plucked_by_bundle_ids(happening_ids)
    bundle_items= where(bundleable_type: 'Resource',bundles: {happening_id:happening_ids}).joins(:bundle, {:resource=> [ :recording,:format]} )\
    .group("bundle_items.bundle_id,recordings.number")\
    .distinct\
    .pluck(Arel.sql("bundle_items.bundle_id, ARRAY[recordings.number::text, string_agg(formats.name, ', ')]"))
    
    return self.nested_array_to_hash( bundle_items )
  end
  
  
  def self.bundle_packages_hashed_and_plucked_by_bundle_ids(happening_ids)
    where(bundleable_type: 'Package',bundles: {happening_id:happening_ids}).joins(:bundle, {package: :format} )\
      .group("bundle_items.bundle_id")\
      .distinct\
      .pluck(Arel.sql("bundle_items.bundle_id, string_agg(formats.name, ', ')")).to_h
  end
  

  private
  
  def self.nested_array_to_hash(nested_array)
       h = Hash.new{ |h,k| h[k]=[] }
       nested_array.each{ |k,v| h[k] << v.flatten }
      h.each { |k, v| h[k] = v } 
      return h
  end 
  
  def rationalise_bundled_resources
    logger.debug "\n\n rationalise_bundled_resources \n\n"
    yield
    self.bundle.bundle_items.by_bundleable_type('Resource').joins(:resource).where('resources.format_id =?', self.package.format_id).delete_all
  end

  
  def no_availability_through_bundled_package
    if (self.bundle.bundle_items.by_bundleable_type('Package').joins(:package).where('packages.format_id =?', self.resource.format_id).any?)
		  self.errors.add(:base, "available through existing bundled package")
		  return false
    end
  end
  
  def brickwall
		self.errors.add(:base, "brick_wall!")
		return false
  end
  
	def verify_destroy
		allow_destroy=   true
		
		errors.add("base", "brick wall.")
		allow_destroy =   false
		(throw :abort )unless allow_destroy
	end
  
end
