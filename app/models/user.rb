class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :account_link

  has_and_belongs_to_many :groups

  def self.from_omniauth(auth)
    account_link = AccountLink.where(provider: auth[:provider], username: auth[:info][:email]).first
    if not account_link then
      user = User.new
      user.email = auth.info.email
      return user
    else
      return account_link.user
    end
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if session["omniauth_email"]
        user.email = session["omniauth_email"] if user.email.blank?
      end
    end
  end
end
