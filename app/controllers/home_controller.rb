require 'signet/oauth_2/client'
require 'google/apis/gmail_v1'

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

  def gmail_service_from_account_link_id(account_link_id)
    account_link = AccountLink.find(account_link_id)
    gmail = Google::Apis::GmailV1::GmailService.new
    oauth_client = Signet::OAuth2::Client.new()
    oauth_client.access_token = account_link.credentials[:token]
    gmail.authorization = oauth_client
    return gmail
  end

  def insert_email_in_user()
  # https://github.com/google/google-api-ruby-client/blob/master/generated/google/apis/gmail_v1/service.rb
  from_gmail = gmail_service_from_account_link_id(params[:from])
  to_gmail = gmail_service_from_account_link_id(params[:to])

  from_sync_label_id = from_gmail.list_user_labels('me').labels.select { |x| x.name == "from_sync" }.map { |x| x.id }.first
  
  to_sync_label_id = to_gmail.list_user_labels('me').labels.select { |x| x.name == "to_sync" }.map { |x| x.id }.first
  if not to_sync_label_id
    new_label = to_gmail.create_user_label('me', Google::Apis::GmailV1::Label.new(name: "to_sync"))
    to_sync_label_id = new_label.id
  end

  messages = from_gmail.list_user_messages('me', label_ids: [from_sync_label_id]).messages
  messages.each do |message_descriptor|
    message = from_gmail.get_user_message('me', message_descriptor.id, format: "RAW")
    inserted_message = to_gmail.insert_user_message('me', {'raw': message.raw}, internal_date_source: "dateHeader", deleted: false)
    to_gmail.modify_message('me', inserted_message.id, Google::Apis::GmailV1::ModifyMessageRequest.new(add_label_ids: [to_sync_label_id]))
  end
  
  render text: [
     from_gmail.get_user_profile('me'),to_gmail.get_user_profile('me')].to_json
  end
end
