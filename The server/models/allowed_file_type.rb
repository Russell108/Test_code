class AllowedFileType < ApplicationRecord
  belongs_to :format
  
  scope :by_format,lambda{|format_id | where(format_id: format_id)}
 
end
