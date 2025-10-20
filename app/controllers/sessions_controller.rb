# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  
  # NEW: OAuth/Entra ID login
  def create_oauth
    auth = request.env['omniauth.auth']
    
    user = User.find_or_create_by(email: auth.info.email) do |u|
      u.name = auth.info.name
      u.entra_id = auth.uid
    end
    
    session[:user_id] = user.id
    redirect_to inbox_queue_path
  end
  
  # OLD: Keep this for admin impersonation/testing
  def create_legacy
    user = User.find_by(id: params[:id])
    
    if user
      session[:user_id] = user.id
      redirect_to inbox_queue_path
    else
      redirect_to root_path, alert: "User not found"
    end
  end
  
  def setup
    # Required by OmniAuth - can be empty
    render plain: 'Setup', status: 404
  end
  
  def failure
    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end
  
  def destroy
    session[:user_id] = nil
    redirect_to root_path
  end
end
