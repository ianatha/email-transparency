class AccountLink < ActiveRecord::Base
	store :credentials, coder: JSON
	belongs_to :user
	has_many :message_id_mapping

	def to_s
		"<#{id}:#{username}>"
	end

	def to_gmail_service
	    gmail_service = Google::Apis::GmailV1::GmailService.new
	    oauth_client = Signet::OAuth2::Client.new(
	      :authorization_uri => 'https://accounts.google.com/o/oauth2/auth',
	      :token_credential_uri =>  'https://www.googleapis.com/oauth2/v3/token',
	      :client_id => ENV["GOOGLE_CLIENT_ID"],
	      :client_secret => ENV["GOOGLE_CLIENT_SECRET"],
	      :refresh_token => self.credentials[:refresh_token],
	    )
	    if Time.at(self.credentials[:expires_at]) < Time.now
	      new_access_token = oauth_client.fetch_access_token
	      self.credentials[:token] = new_access_token['access_token']
	      self.credentials[:expires_at] = (Time.now + new_access_token['expires_in']).to_i
	      self.save
	    end
	    oauth_client.access_token = self.credentials[:token]
	    gmail_service.authorization = oauth_client
	    return gmail_service
	end
end
