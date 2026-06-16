class CentreFormat < ApplicationRecord


    # when centre format changed to Not current
    # update relevant  packages to be unpurchasable this also deletes bundle
    # update relevant  resources to be unpurchasable
    #  when a centre format is archived/deleted delete default resources & packages for courses & happenings
    # cannot create a centre multi format unless child centre formats exist & are current
    # if a format is archived parent formats are alos archived
  #centre id    Centre
  

########################################  callbacks  #######################################
#
   before_destroy :verify_destroy
#    before_save :round_prices
#    after_save    :mark_package_and_resources_as_unpurchasable, :if => Proc.new { |format| format.current_changed?  &&  (format.current==false)}
#    after_save    :remove_default_p_and_p, :if => Proc.new { |format| format.current_changed?  &&  (format.current==false)}
########################################  associations  #######################################
#
  belongs_to :centre
  belongs_to :format
  


	
  validates_inclusion_of :current, :in => [true, false]
  validates_uniqueness_of   :format, :scope => [:centre]

#  #######################################  scopes  #######################################

#    #######################################  public methods  #######################################
 
#
#  #######################################  private methods  #######################################
#
#  private
#

    def verify_destroy
        allow_destroy = true
         
        #check for resource relating to centre
        if Resource.by_happening_centre(centre_id).by_format(format_id).any?
            errors.add(:format, " #{format.name}: Centre Resources exist!!")
            allow_destroy= false 
        end

        if Resource.by_course_centre(centre_id).by_format(format_id).any?
            errors.add(:format, " #{format.name}: Course Resources exist!!")
            allow_destroy= false 
        end

        #check for packages relating to centre
        if Package.by_happening_centre(centre_id).by_format(format_id).any?
            errors.add(:format, " #{format.name}: Centre Packages exist!!")
            allow_destroy= false 
        end

        if Package.by_course_centre(centre_id).by_format(format_id).any?
            errors.add(:format, " #{format.name}: Course Packages exist!!")
            allow_destroy= false 
        end
        
        # check for default items
        if DefaultItem.for_centre_events(centre_id).by_format(format_id).any?
          errors.add(:format, " #{format.name}: Default Event Items exist!!")
        end
        
        if DefaultItem.for_centre_meets(centre_id).by_format(format_id).any?
          errors.add(:format, " #{format.name}: Default Meet Items exist!!")
        end
        
        if DefaultItem.for_centre_courses(centre_id).by_format(format_id).any?
          errors.add(:format, " #{format.name}: Default Course Items exist!!")
        end
        if DefaultItem.for_centre_default_bundles(centre_id).by_format(format_id).any?
          errors.add(:format, " #{format.name}: Default course bundle  Items exist!!")
        end
        # prevent any destroy 
     #    errors.add(:base, " im a brick wall!!")
     #   allow_destroy= false 
        (throw :abort )unless allow_destroy
    end

  
end

