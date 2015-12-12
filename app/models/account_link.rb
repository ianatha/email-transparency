class AccountLink < ActiveRecord::Base
	store :credentials, coder: JSON
end
