class HomeController < ApplicationController
  def loggedout_index
    if current_user == nil
      render
    else
      redirect_to "/home"
    end
  end

  def loggedin_index
    authenticate_user!
  end

  def link_account
    auth = request.env["omniauth.auth"]
    if current_user
      # We're logged in; we're just adding accounts to our user
      account_link = current_user.account_link.where(provider: auth[:provider], username: auth[:info][:email]).first
      if account_link
        flash[:notice] = "updated existing link with #{auth[:provider]}"
        new_credentials = account_link.credentials
        new_credentials[:token] = auth[:credentials][:token]
        new_credentials[:expires_at] = auth[:credentials][:expires_at]
        new_credentials[:expires] = auth[:credentials][:expires]
        if not new_credentials[:refresh_token]
          new_credentials[:refresh_token] = auth[:credentials][:refresh_token]
        end
        account_link.update(credentials: new_credentials)
      else
        account_link = current_user.account_link.new(provider: auth[:provider], username: auth[:info][:email], credentials: auth[:credentials])
        flash[:notice] = "inserted new link with #{auth[:provider]}"
      end
      redirect_to "/home"
    else
      # We're not logged in!

      @user = User.from_omniauth(request.env["omniauth.auth"])
      if @user.persisted?
        print "HERE"
        sign_in_and_redirect(@user, :event => :authentication)
      elsif @user.email.end_with? "@mamabear.io"
        auth_info = request.env["omniauth.auth"]
        session["omniauth_email"] = auth_info[:info][:email]
        session["omniauth_creds"] = auth_info[:credentials]
        redirect_to new_user_registration_url
      else
        redirect_to "/"
      end
    end
  end
end
