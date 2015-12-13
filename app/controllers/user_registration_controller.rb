class UserRegistrationController < Devise::RegistrationsController
  def new
    super
  end

  def create
  	 super

	if session["omniauth_creds"]
		account_link = AccountLink.new(user_id: current_user.id, provider: 'google_oauth2', username: current_user.email, credentials: session["omniauth_creds"])
		account_link.save
	end

	session["omniauth_email"] = nil
	session["omniauth_creds"] = nil
  end

  def update
    super
  end
end 

