class HomeController < ApplicationController
  before_filter :authenticate_user!

  def index
  end

  def link_account
    auth = request.env["omniauth.auth"]
    other_account_links = current_user.account_link.where(provider: auth[:provider], username: auth[:info][:email]).to_a
    if other_account_links.length
      other_account_links.each do |a|
        a.delete
      end
      flash[:notice] = "updated existing link with #{auth[:provider]}"
    else
      flash[:notice] = "inserted new link with #{auth[:provider]}"
    end
    account_link = current_user.account_link.create(provider: auth[:provider], username: auth[:info][:email], credentials: auth[:credentials])
    redirect_to "/home"
  end
end
