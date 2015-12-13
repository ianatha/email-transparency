class AccountLink < ActiveRecord::Base
	store :credentials, coder: JSON
	belongs_to :user
	has_many :message_id_mapping

	def to_s
		"<#{id}:#{username}>"
	end
end
