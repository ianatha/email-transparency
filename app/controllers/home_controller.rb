class HomeController < ApplicationController
  before_filter :authenticate_user!

  def index
  end

  def link_account
    auth = request.env["omniauth.auth"]
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
  end
end
