class AddHistoryIdToAccountLink < ActiveRecord::Migration
  def change
    add_column :account_links, :history_id, :string
  end
end
