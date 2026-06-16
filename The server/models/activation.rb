class Activation < ApplicationRecord
	
	attribute :reset_password,:boolean
#	attribute :colour,:string
	attribute :password,:string
	attribute :password_confirmation,:string
	attribute :init_agree,:date
	attribute :forename,:string
	attribute :surname,:string
	attribute :email,:string
	attribute :d_o_b,:date

	#====================================   callbacks   ===============================================
	
	#before_validation :downcase_colour, :unless => Proc.new{ |a|  a.colour.blank? }
	
	#====================================   validations   ===============================================
	validates_presence_of :token
	validates_inclusion_of :agreement , in: [true], message: "Please read confirm your agreement"
	validates_length_of :password, :within => Devise.password_length, :unless => Proc.new{ |act|  act.init_agree}
	validates_confirmation_of :password, :unless => Proc.new{ |act|  act.init_agree}
#	validates_presence_of :colour, :unless => Proc.new{ |act|  act.init_agree}
#	validates_format_of :colour, :with =>  /\A[a-z\s]+\Z/  , :allow_blank => true,
#						message: "please use characters a-z or spaces"
	validate :no_stupid_passwords ,    :if => :password_validation_required?
	#====================================      ===============================================
	private

	def password_validation_required?
    logger.debug "\n\n password_validation_required?\n\n"
	   password != nil
	end
	  
	def no_stupid_passwords
    logger.debug "\n\nno_stupid_passwords\n\n"
	 #  allowed=true
	  password = self.password.downcase.strip
		( return )if (forename.blank? || surname.blank?)
	    if ((password.include? self.forename.downcase) || (self.password.strip.downcase.include? self.surname.downcase))
	     errors.add(:password, "You cannot use your forename or surname sequentially in your password.") 
	
	       throw(:abort)
		end
	
		if (password.include? self.email.downcase)
      
		    errors.add(:password,"You cnnot use your email sequentially in your password.")  
		    throw(:abort)
		end
	  
		BannedPassword.all.collect(&:name).each do |banned|
		  if ((self.password.strip.include? banned) )
		
		     errors.add(:password, "As it stands your chosen password  is considered insecure ==>\"#{banned}\" <==. 
		       Please adapt your password or choose another. For example: use a number 0 instead of a letter O. Thank you!!".html_safe )
		
		        throw(:abort)
		  end
		end

	end

#	def downcase_colour
#	    self.colour = self.colour.downcase.strip
#	end	
end
