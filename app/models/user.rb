class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :account_link

  def self.from_omniauth(auth)
    account_link = AccountLink.where(provider: auth[:provider], username: auth[:info][:email]).first_or_create do |account_link|
      user = User.new
      user.email = auth.info.email
      user.password = Devise.friendly_token[0,20]
      account_link.user = user
      account_link.credentials = auth[:credentials]
    end

    return account_link.user
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.omniauth_auth"]
        user.username = data["email"] if user.email.blank?
      end
    end
  end
end
