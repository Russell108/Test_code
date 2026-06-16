class SalesScope < ApplicationRecord

  # defines who is entitled to purchase items from the course
  # one of:
  #  1 onkly Affiliates can purchase
  #  2 Members can purchase
  #  3 Admin aloocated sales ok
  #  4 Epublically purchasable

	belongs_to :course
  belongs_to :happening
	# Prevent creation of new records and modification to existing records
# def readonly?
#   return true
# end
 
  # Prevent objects from being destroyed
  def before_destroy
    raise ActiveRecord::ReadOnlyRecord
  end

   def delete
    raise ActiveRecord::ReadOnlyRecord
  end

   def self.delete_all(conditions = nil)
    raise ActiveRecord::ReadOnlyRecord
  end

  def self.update_all(conditions = nil)
    raise ActiveRecord::ReadOnlyRecord
  end
end
