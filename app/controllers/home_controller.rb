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
    thread_mapping = {}

    # https://github.com/google/google-api-ruby-client/blob/master/generated/google/apis/gmail_v1/service.rb
    from_gmail = gmail_service_from_account_link_id(params[:from_account_id])
    to_gmail = gmail_service_from_account_link_id(params[:to_account_id])

    from_sync_labels = from_gmail.list_user_labels('me').labels.select { |x| x.name.start_with? "MB/" }
    from_sync_label_names = from_sync_labels.map { |x| x.name }
    if not from_sync_label_names
      raise "Couldn't find label"
    end

    to_sync_labels = to_gmail.list_user_labels('me').labels.select { |x| from_sync_label_names.include?(x.name) }
    to_sync_label_names = to_sync_labels.map { |x| x.name }

    label_mappings = {}

    from_sync_labels.each do |label| 
      if not to_sync_label_names.include?(label.name)
        new_label = to_gmail.create_user_label('me', Google::Apis::GmailV1::Label.new(name: label.name))
        label_mappings[label.id] = new_label.id
      else 
        label_mappings[label.id] = to_sync_labels.select { |x| x.name == label.name }.first.id
      end
    end

    message_ids = from_gmail.list_user_messages('me', label_ids: from_sync_labels.map { |x| x.id }).messages
    message_count = 0

    from_gmail.batch do |from_gmail|
      message_ids.each do |message_id|
        from_gmail.get_user_message('me', message_id.id, format: "RAW") do |message, err|
          puts message
          transcribed_message = Google::Apis::GmailV1::Message.new(raw: message.raw)
          transcribed_message.label_ids = message.label_ids.map { |label_id| label_mappings[label_id] }
          transcribed_message.thread_id = thread_mapping[message.thread_id] if thread_mapping[message.thread_id]
          inserted_message = to_gmail.insert_user_message('me', transcribed_message, internal_date_source: "dateHeader", deleted: false)
          thread_mapping[message.thread_id] = inserted_message.thread_id
          message_count = message_count + 1
        end
      end
    end

    render json: {
      message_count: message_count,
      from: from_gmail.get_user_profile('me'),
      to: to_gmail.get_user_profile('me')
    }
  end
end
