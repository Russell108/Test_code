class UserSearch 
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :id , :integer
  attribute :search , :string
 #atribute :purpose  , :string
 #atribute :parent_type, :string
 #atribute :parent_id, :integer
end
