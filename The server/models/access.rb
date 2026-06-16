class Access < ApplicationRecord

	#joins table to define which talk types each talk type can have access to

	strip_attributes :collapse_spaces => true
	#====================================   associations   ===============================================
	belongs_to :talk_type
	belongs_to :access_type, :class_name => "TalkType"
  belongs_to :family_group, :class_name => "TalkType", foreign_key: :access_type_id 

	#====================================   validations   ===============================================
	validates_presence_of :talk_type, :access_type
#	validates_exclusion_of :access_type_id, in: [4], message: "In valid type" , :unless => Proc.new{ |access|  access.talk_type_id == 4 }
	validates_uniqueness_of :access_type, scope: :talk_type, message:"has already been assigned"
  #validate :brickwall
  #before_destroy :verify_destroy 
  #====================================   public methods   ===============================================

  def self.grouped_by_talk_type
    accesses = self.all
    .group(:talk_type_id)
    .pluck(Arel.sql("talk_type_id, array_agg( ARRAY[access_type_id, id])" ))
    self.nested_array_to_nested_hashy accesses
  end
 
 
  #====================================   Private Methods   ===============================================
  	private
  
    def self.nested_array_to_nested_hashy(nested_array)
      h = Hash.new{ }
      nested_array.each{ |k,v| h[k] = v.to_h }
      return h
    end
 
  
  def self.nested_array_to_nested_hash(nested_array)
       h = Hash.new{ |h,k| h[k]=[] }
       nested_array.each{ |k,v| h[k] << v }
      h.each { |k, v| h[k] = v.to_h } 
      return h
  end
  
  #def brickwall
	#	self.errors.add(:base, "brick_wall!")
	#	return false
  #end
  #
	#def verify_destroy
	#	allow_destroy=   true
	#	
	#	errors.add("base", "brick wall.")
	#	allow_destroy =   false
	#	(throw :abort )unless allow_destroy
	#end
end
