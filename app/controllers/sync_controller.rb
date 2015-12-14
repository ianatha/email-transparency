require 'signet/oauth_2/client'
require 'google/apis/gmail_v1'
require 'mail'

Google::Apis.logger.level = Logger::WARN

class SyncController < ApplicationController
  before_filter :authenticate_user!
  
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

    if from_message_ids.size == 0
      return 0
    end

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
            mapped_thread_id = ThreadIdMapping.where(from_account_link_id: from_account_link.id, from_thread_id: message_id.thread_id, to_account_link_id: to_account_link.id).first
            if not mapped_thread_id
              mapped_thread_id = ThreadIdMapping.where(to_account_link_id: from_account_link.id, to_thread_id: message_id.thread_id, from_account_link_id: to_account_link.id).first_or_create
            end

            # we should first check if the email already exists in the target account
            message_already_in_to_gmail = to_gmail.list_user_messages('me', q: "rfc822msgid:#{email_message_id}")
            raise "More than one message with the same Message-Id. Shenanings!" if message_already_in_to_gmail.messages and message_already_in_to_gmail.messages.size > 1
            if message_already_in_to_gmail and message_already_in_to_gmail.messages
              message_already_in_to_gmail = message_already_in_to_gmail.messages.first

              label_ids_to_have = message.label_ids.map { |label_id| label_mappings[label_id] }.compact
              if label_ids_to_have.size > 0
                to_gmail.modify_message('me', message_already_in_to_gmail.id, Google::Apis::GmailV1::ModifyMessageRequest.new(add_label_ids: label_ids_to_have))
              end

              if mapped_thread_id.from_account_link_id == from_account_link.id
                mapped_thread_id.to_thread_id = message_already_in_to_gmail.thread_id
              elsif mapped_thread_id.from_account_link_id == to_account_link.id
                mapped_thread_id.from_thread_id = message_already_in_to_gmail.thread_id
              end

              message_mapping.provider_message_id = message_already_in_to_gmail.id
              message_mapping.provider_thread_id = message_already_in_to_gmail.thread_id
            else
              transcribed_message = Google::Apis::GmailV1::Message.new(raw: message.raw)
              transcribed_message.label_ids = message.label_ids.map { |label_id| label_mappings[label_id] } + extra_labels
              if mapped_thread_id.to_account_link_id == to_account_link.id and mapped_thread_id.to_thread_id
                transcribed_message.thread_id = mapped_thread_id.to_thread_id
              elsif mapped_thread_id.from_account_link_id = to_account_link.id and mapped_thread_id.from_thread_id
                transcribed_message.thread_id = mapped_thread_id.from_thread_id
              end

              inserted_message = to_gmail.insert_user_message('me', transcribed_message, internal_date_source: "dateHeader", deleted: false)

              message_count = message_count + 1

              if mapped_thread_id.from_account_link_id == from_account_link.id
                mapped_thread_id.to_thread_id = inserted_message.thread_id
              elsif mapped_thread_id.from_account_link_id == to_account_link.id
                mapped_thread_id.from_thread_id = inserted_message.thread_id
              end

              message_mapping.provider_message_id = inserted_message.id
              message_mapping.provider_thread_id = inserted_message.thread_id
            end
            
            mapped_thread_id.save
            message_mapping.save
          end
        end
      end
    end

    return message_count
  end

  # GmailServive documentation: https://github.com/google/google-api-ruby-client/blob/master/generated/google/apis/gmail_v1/service.rb
  def sync_via_query(from_account_link, to_account_link, from_gmail, to_gmail, from_sync_labels, label_mappings, extra_labels)
    threads = from_gmail.list_user_threads('me', label_ids: from_sync_labels.map { |x| x.id }).threads

    message_count = if threads 
      thread_history_id = threads.map { |x| x.history_id.to_i }.max

      from_message_ids = threads_to_message_ids(from_gmail, threads)
      message_count = sync_messages(from_account_link, to_account_link, from_gmail, to_gmail, from_message_ids, label_mappings, extra_labels)

      from_account_link.history_id = thread_history_id
      from_account_link.save

      message_count
    else
      0
    end

    result = {
      message_count: message_count,
      from: {
        username: from_account_link.username,
        history_id: from_account_link.history_id,
      },
      to: to_account_link.username,
      method: "query",
    }

    return result
  end

  def sync_via_history(from_account_link, to_account_link, from_gmail, to_gmail, from_sync_labels, label_mappings, extra_labels)
    histories = from_gmail.list_user_histories('me', start_history_id: from_account_link.history_id)

    from_message_ids = []

    if histories.history
      histories.history.each do |event|
        if event.messages_added then 
          event.messages_added.each do |message_added|
            if from_account_link.message_id_mapping.where(provider_thread_id: message_added.message.thread_id).size > 0 or
                message_added.message.label_ids.any? { |x| label_mappings[x] }
              from_message_ids = from_message_ids + [message_added.message]
            end
          end
        end

        if event.labels_added then
          event.labels_added.each do |label_added|
            # if any of the added labels is being mapped
            if label_added.label_ids.any? { |x| label_mappings[x] } or
                from_account_link.message_id_mapping.where(provider_thread_id: label_added.message.thread_id).size > 0
              from_message_ids = from_message_ids + [label_added.message]
            end
          end
        end
      end
    end

    message_count = sync_messages(from_account_link, to_account_link, from_gmail, to_gmail, from_message_ids, label_mappings, extra_labels)

    from_account_link.history_id = histories.history_id
    from_account_link.save

    result = {
      message_count: message_count,
      from: {
        username: from_account_link.username,
        history_id: from_account_link.history_id,
      },
      to: to_account_link.username,
      method: "history",
    }
    
    return result
  end

  def sync(from_account_link = nil, to_account_link = nil)
    from_account_link = from_account_link || current_user.account_link.find(params[:from_account_id])
    to_account_link = to_account_link || current_user.account_link.find(params[:to_account_id])

    raise "Can't sync to the same account" if from_account_link == to_account_link

    puts "Syncing #{from_account_link} -> #{to_account_link}"

    from_gmail = from_account_link.to_gmail_service()
    to_gmail = to_account_link.to_gmail_service()

    from_sync_labels = from_gmail.list_user_labels('me').labels.select { |label| from_account_link.user.groups.any? { |group| group.label_matches_publish_rules?(label.name) }}
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

    extra_labels = [ "UNREAD", "INBOX" ]

    if not from_account_link.history_id
      result = sync_via_query(from_account_link, to_account_link, from_gmail, to_gmail, from_sync_labels, label_mappings, extra_labels)
    else
      result = sync_via_history(from_account_link, to_account_link, from_gmail, to_gmail, from_sync_labels, label_mappings, extra_labels)
    end

    if request && params[:from_account_id]
      render json: result
    else
      return result
    end
  end

  def sync_all()
    result = []
    AccountLink.all.each do |from|
      AccountLink.all.each do |to|
        if from != to
          result = result + [sync(from, to)]
        end
      end
    end

    render json: result
  end

  def access_check()
    result = {}
    AccountLink.all.each do |acct|
      begin
        from_gmail = acct.to_gmail_service()
        from_gmail.get_user_profile('me')
        result[acct.username] = "ok"
      rescue StandardError => boom
        result[acct.username] = "fail: #{boom}"
      end
      if not acct.credentials[:refresh_token]
        result[acct.username] = " - missing refresh_token"
      end
    end

    render json: result
  end

  def add_watch(account_link = nil)
    account_link = account_link || current_user.account_link.find(params[:account_link_id])
    gmail = account_link.to_gmail_service()
    result = gmail.watch('me', Google::Apis::GmailV1::WatchRequest.new(topic_name: "projects/email-transparency/topics/gmail-api"))
    render json: result
  end

  def reset_history_id()
    AccountLink.all.each do |account|
      account.history_id = nil
      account.save
    end
    render json: true
  end
end
