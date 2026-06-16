class DefaultItem < ApplicationRecord
  
  validates_uniqueness_of :format_id, scope: [:type, :defaultable]
  
  belongs_to :defaultable, polymorphic: true
  belongs_to :happening, foreign_key: :defaultable_id, class_name: 'Happening', optional: :true
  belongs_to :course, foreign_key: :defaultable_id, class_name: 'Course', optional: :true
  belongs_to  :default_bundle, foreign_key: :defaultable_id, class_name: 'DefaultBundle', optional: :true
  belongs_to :format
  
  
  scope  :for_centre_events, ->(centre_id) {  where("default_items.defaultable_type = ? and happenings.type = ? and happenings.happenable_id =?",'Happening', 'Event',centre_id)
                                              .joins(:happening)}
  scope  :for_centre_meets, ->(centre_id) {  where("default_items.defaultable_type = ? and happenings.type = ? and courses.centre_id =?",'Happening', 'Meet',centre_id)
                                              .joins(happening: :course)}
  scope  :for_centre_courses, ->(centre_id) {  where("default_items.defaultable_type = ? and courses.centre_id =?", 'Course',centre_id)
                                              .joins( :course)}
  scope  :for_centre_default_bundles, ->(centre_id) {  where("default_items.defaultable_type = ? and courses.centre_id =?", 'DefaultBundle',centre_id)
                                              .joins(default_bundle: :course)}
                                              
  scope :by_format, ->(format_id) {  where(format_id: format_id)}
end
