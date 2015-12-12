class CreateMessageIdMappings < ActiveRecord::Migration
  def change
    create_table :message_id_mappings do |t|
      t.string :email_message_id
      t.integer :account_link_id
      t.string :provider_message_id
      t.string :provider_thread_id

      t.timestamps null: false
    end
    add_index :message_id_mappings, :email_message_id
    add_index :message_id_mappings, :account_link_id
  end
end
