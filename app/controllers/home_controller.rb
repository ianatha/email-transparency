class HomeController < ApplicationController
  before_filter :authenticate_user!

  def index
  end

  def link_account
    auth = request.env["omniauth.auth"]
    account_link = current_user.account_link.where(provider: auth[:provider], username: auth[:info][:email]).first
    if account_link
      flash[:notice] = "updated existing link with #{auth[:provider]}"
    else
      account_link = current_user.account_link.new(provider: auth[:provider], username: auth[:info][:email])
      flash[:notice] = "inserted new link with #{auth[:provider]}"
    end
    account_link.update(credentials: auth[:credentials])
    redirect_to "/home"
  end
end
