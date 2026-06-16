class Price
 include ActiveModel::Model
  attr_accessor  :amount


  


  def rounded_price
  		
   pounds = amount.div 100
   pennies =  amount % 100


   if( pennies <= 10 )
     pennies = 95
     pounds = pounds -1
   elsif (pennies <= 35 )
     pennies = 25
   elsif(pennies <= 60 )
     pennies = 45
   elsif(pennies<= 85 )
     pennies = 75
   else
     pennies = 95
  end
  price = (pounds * 100 + pennies)
  (price =0 )if( price <= 0)
  return price.to_d
   end
end
