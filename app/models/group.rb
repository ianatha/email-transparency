class Group < ActiveRecord::Base
	store :rules, coder: JSON
	has_and_belongs_to_many :users

	def label_matches_publish_rules?(label)
		return false if not rules[:publish] or not rules[:publish][:includeLabels]
		if Regexp.new(rules[:publish][:includeLabels]).match(label)
			return true
		else
			return false
		end
	end

	def to_s
		"Group<#{id}:#{name}>"
	end
end
