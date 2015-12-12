class CreateAccountLinks < ActiveRecord::Migration
  def change
    create_table :account_links do |t|
      t.string :provider
      t.string :username
      t.text :credentials
      t.integer :user_id

      t.timestamps null: false
    end
  end
end
