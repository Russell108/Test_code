class AllowedExtension < ApplicationRecord
  belongs_to :format
  belongs_to :extension
  validates_associated :extension
  accepts_nested_attributes_for :extension
  
  validates_uniqueness_of :extension, scope: :format
end
