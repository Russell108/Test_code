class ResourceSearch < ApplicationRecord
  attr_accessor :happening_policy_scope,   :resource_policy_scope, :recording_policy_scope
  
  
  belongs_to :speaker ,  optional: true
  belongs_to :centre ,  optional: true
  
  
  ###########################.  Transcription.  #####################################################
  # maps the column :transcription_status to these readable names
  enum :transcription_status,{
    bypassed: 0,  
    requested: 1, 
    preparing: 2, # Worker B is currently unzipping/downloading
    prepared: 3,  # Worker B is DONE; Chunks are ready for Worker A
    processing: 4,# Worker A is actively transcribing not needed
    completed: 5, 
    failed: 6 
  }
  #priority. set if transcription required leave null if not required

  
  
  
  def happenings
  	happenings ||=find_happenings.order("happenings.start_date DESC").distinct.limit(10)
    
  end 
  
  
  
  def resources
  	resources ||=find_resources.distinct
  end 
  
  def recordings
  	recordings ||=find_recordings.distinct
  end 
  


	private
  
  def find_happenings
    if( search_conditions[0].empty?)
      
      hash_of_joins ={}
      flattened_conditions =""
    else
      flattened_conditions =  [search_conditions[0].join(" AND "), *search_conditions[1]]
      hash_of_joins =[:action_text_rich_text, {recordings: {contributions: :speaker}}]
      end
		happenings= happening_policy_scope.where(flattened_conditions )
    .left_outer_joins(hash_of_joins)
                        
    
  end
 
  def find_resources
    if( search_conditions[0].empty?)
      logger.debug "\n\nfind_resources if( search_conditions[0].empty?)\n\n"
      hash_of_joins ={}
      flattened_conditions =""
    else
       logger.debug "\n\nfind_resources else)\n\n"
      flattened_conditions =  [search_conditions[0].join(" AND "), *search_conditions[1]]
      hash_of_joins =[:happening, {contributions: :speaker}]
    end
		resources= resource_policy_scope
    .where(flattened_conditions )
    .left_outer_joins(hash_of_joins)
    
  end 
  
 
  def find_recordings
    if( search_conditions[0].empty?)
      logger.debug "\n\nfind_resources if( search_conditions[0].empty?)\n\n"
      
      hash_of_joins ={}
      flattened_conditions =""
    else
       logger.debug "\n\nfind_resources else)\n\n"
      flattened_conditions =  [search_conditions[0].join(" AND "), *search_conditions[1]]
      hash_of_joins ={happening: {contributions: :speaker}}
    end
		recordings= recording_policy_scope
    .where(flattened_conditions )
    .left_outer_joins(hash_of_joins)
    
  end 
 
 


	def search_conditions
   # logger.debug "\n\nself self.inspect #{self.inspect}\n\n"
      conditions = []
		  parameters = []
      
    if digest_date
      conditions << "( recordings.updated_at BETWEEN ? and ?  OR recordings.updated_at BETWEEN ? and ?) OR
      ( acquired_resources.updated_at BETWEEN ? and ?  and  acquired_resources.user_id = ?) OR
      ( acquired_packages.updated_at BETWEEN ? and ?  and  acquired_packages.user_id = ?)"
      parameters << digest_date.days_ago(7).beginning_of_day
      parameters << digest_date.end_of_day
      parameters << digest_date.days_ago(7).beginning_of_day
      parameters << digest_date.end_of_day
      parameters << digest_date.days_ago(7).beginning_of_day
      parameters << digest_date.end_of_day 
      parameters << user_id
      parameters << digest_date.days_ago(7).beginning_of_day
      parameters << digest_date.end_of_day 
      parameters << user_id
    end
    
     
    if happening_id.blank?
     	unless self.text_search.blank?
    		conditions << "(happenings.searchable_text ILIKE ? or recordings.searchable_text ILIKE ?\
    						or happenings.searchable_text @@ ? or recordings.searchable_text @@ ? )"
    		parameters << "%#{text_search}%"
    		parameters << "%#{text_search}%"
    		parameters << text_search
    		parameters << text_search
     	end
      
      
    	
    	unless speaker_id.blank?
    		 conditions << "contributions.speaker_id = (?)" 
    	    parameters << speaker_id
    	end
    
    	if start_date
    	   conditions << "recordings.start_datetime >= ?"
    	   parameters << start_date #.to_time.utc 
    	end	
    
    	if end_date
    	   conditions << " recordings.start_datetime <= ?"
    	   parameters << end_date 
    	end
    else
    	conditions << "(happenings.id = ?)"
    	parameters <<   happening_id
    end
    
    unless transcription_status.blank?
 	   conditions << "recordings.transcription_status = ?"
    status = Recording.transcription_statuses[transcription_status ]
     logger.debug "\n\nstatus: #{status}\n\n"
 	   parameters <<  status
    end
    
    unless happening_type.blank?
      conditions << "happenings.type = ?" 
      parameters << happening_type
    end

    #  return "" if ((conditions ==[]) and (parameters == []))
		return [conditions, parameters]
	end
end
