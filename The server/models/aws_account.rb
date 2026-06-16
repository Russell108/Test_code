class AwsAccount < ApplicationRecord
  
  has_many  :buckets
end
