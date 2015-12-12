class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def index
  	if current_user == nil
  		render text: "you're not logged in"
  	else
  		redirect_to "/home"
  	end
  end
end
