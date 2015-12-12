class AccountLink < ActiveRecord::Base
	store :credentials, coder: JSON
	has_many :message_id_mapping
end
