class CreateThreadIdMappings < ActiveRecord::Migration
  def change
    create_table :thread_id_mappings do |t|
      t.integer :from_account_link_id
      t.string :from_thread_id
      t.integer :to_account_link_id
      t.string :to_thread_id

      t.timestamps null: false
    end
  end
end
