require 'signet/oauth_2/client'
require 'google/apis/gmail_v1'
require 'mail'

Google::Apis.logger.level = Logger::WARN

class SyncController < ApplicationController
  def gmail_service_from_account_link(account_link)
    gmail = Google::Apis::GmailV1::GmailService.new
    oauth_client = Signet::OAuth2::Client.new(
      :authorization_uri => 'https://accounts.google.com/o/oauth2/auth',
      :token_credential_uri =>  'https://www.googleapis.com/oauth2/v3/token',
      :client_id => ENV["GOOGLE_CLIENT_ID"],
      :client_secret => ENV["GOOGLE_CLIENT_SECRET"],
      :refresh_token => account_link.credentials[:refresh_token],
    )
    if Time.at(account_link.credentials[:expires_at]) < Time.now
      result = oauth_client.fetch_access_token
      account_link.credentials[:token] = result['access_token']
      account_link.credentials[:expires_at] = (Time.now + result['expires_in']).to_i
      account_link.save
    end
    oauth_client.access_token = account_link.credentials[:token]
    gmail.authorization = oauth_client
    return gmail
  end

  def get_message_id(message_raw)
    email = Mail.new(message_raw)
    return email.header['Message-Id']
  end

  def threads_to_message_ids(from_gmail, threads)
    result = []
    from_gmail.batch do |from_gmail|
      threads.each do |thread|
        from_gmail.get_user_thread('me', thread.id, format: 'minimal') do |thread, err|
          raise err if err

          result = result + thread.messages
        end
      end
    end
    return result
  end

  def sync_messages(from_account_link, to_account_link, from_gmail, to_gmail, from_message_ids, label_mappings, extra_labels)
    message_count = 0

    from_gmail.batch do |from_gmail|
      from_message_ids.each do |message_id|
        from_gmail.get_user_message('me', message_id.id, format: "RAW") do |message, err|
          raise err if err

          email_message_id = get_message_id(message.raw).value

          # have we seen this message before?
          from_message_mapping = from_account_link.message_id_mapping.where(email_message_id: email_message_id).first_or_create do |message_mapping|
            message_mapping.provider_message_id = message_id.id
            message_mapping.provider_thread_id = message_id.thread_id
          end

          to_message_mapping = to_account_link.message_id_mapping.where(email_message_id: email_message_id).first_or_create do |message_mapping|
            # if we're in here, it means the message hasn't been 'mapped' before

            # have we mapped this thread before?
            mapped_thread_id = ThreadIdMapping.where(from_account_link_id: from_account_link.id, from_thread_id: message_id.thread_id, to_account_link_id: to_account_link.id).first_or_create

            transcribed_message = Google::Apis::GmailV1::Message.new(raw: message.raw)
            transcribed_message.label_ids = message.label_ids.map { |label_id| label_mappings[label_id] } + extra_labels
            transcribed_message.thread_id = mapped_thread_id.to_thread_id if mapped_thread_id.to_thread_id

            inserted_message = to_gmail.insert_user_message('me', transcribed_message, internal_date_source: "dateHeader", deleted: false)

            message_count = message_count + 1

            mapped_thread_id.to_thread_id = inserted_message.thread_id
            mapped_thread_id.save

            message_mapping.provider_message_id = inserted_message.id
            message_mapping.provider_thread_id = inserted_message.thread_id
            message_mapping.save
          end
        end
      end
    end

    return message_count
  end

  # GmailServive documentation: https://github.com/google/google-api-ruby-client/blob/master/generated/google/apis/gmail_v1/service.rb
  def sync()
    from_account_link = current_user.account_link.find(params[:from_account_id])
    to_account_link = current_user.account_link.find(params[:to_account_id])
    raise "Can't sync to the same account" if from_account_link == to_account_link

    from_gmail = gmail_service_from_account_link(from_account_link)
    to_gmail = gmail_service_from_account_link(to_account_link)

    from_sync_labels = from_gmail.list_user_labels('me').labels.select { |x| x.name.downcase.start_with? "mb/" }
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

    threads = from_gmail.list_user_threads('me', label_ids: from_sync_labels.map { |x| x.id }).threads
    thread_history_id = threads.map { |x| x.history_id.to_i }.max

    from_message_ids = threads_to_message_ids(from_gmail, threads)
    message_count = sync_messages(from_account_link, to_account_link, from_gmail, to_gmail, from_message_ids, label_mappings, (Rails.env.production? ? [ "INBOX", "UNREAD" ] : []))

    from_account_link.history_id = thread_history_id
    from_account_link.save

    render json: {
      message_count: message_count,
      from: from_gmail.get_user_profile('me'),
      to: to_gmail.get_user_profile('me')
    }
  end
end
