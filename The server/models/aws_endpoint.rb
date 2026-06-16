class AwsEndpoint < ApplicationRecord
  
  has_many :account_endpoint_buckets, class_name: 'Bucket', foreign_key: "aws_account_endpoint_id"
  has_many :subdomain_endpoint_buckets, class_name: 'Bucket', foreign_key: "aws_subdomain_endpoint_id"
  
  validates_uniqueness_of :name
  validates_presence_of   :name
  
   before_destroy :verify_destroy
   
   
   private
   def verify_destroy
     allow_destroy =true
     logger.debug "\n\naccount_endpoint_buckets #{account_endpoint_buckets.size}\n\n"
     unless (self.account_endpoint_buckets.empty? )         
         errors.add(:base, "is connected to at least one account endpoint buckets ")
         allow_destroy=   false
     end
     
     unless (self.subdomain_endpoint_buckets.empty? )         
         errors.add(:base, "is connected to at least one subdomain endpoint buckets ")
         allow_destroy=   false
     end
   
     #  errors.add(:bucket, "brick wall")
     #    allow_destroy=   false
      (throw :abort )unless allow_destroy
   end
end
