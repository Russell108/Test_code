class Extension < ApplicationRecord
  has_many :allowed_extensions
  has_many :formats, through: :allowed_extensions
  validates :title,  presence: true
  validates :title, length: { maximum: 12 }
end
