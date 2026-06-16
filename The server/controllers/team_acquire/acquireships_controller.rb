class TeamAcquire::AcquireshipsController < Acquire::AcquireshipsController
   before_action :authenticate_user! 
  def index
    @controller_first_namespace ="team_acquire"
    @team ="group"
    super
  end
  
  
end

