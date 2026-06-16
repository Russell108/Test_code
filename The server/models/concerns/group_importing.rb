module GroupImporting
  extend ActiveSupport::Concern

  included do
  end
  
  
  def self.results_array_from_import(group_users_size, import_result, start_message)
    import_size =import_result.ids.size
     errors=["<u class='text-dark'>#{group_users_size- import_size} #{start_message}:</u><BR>"]
    import_result.failed_instances.each do |instance| 
      instance.errors.full_messages.each do |message|
        errors |= [message]
      end
    end
    return[import_result.ids, errors]
  end
  
end