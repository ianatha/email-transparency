# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20151214001341) do

  create_table "account_links", force: :cascade do |t|
    t.string   "type"
    t.string   "username"
    t.text     "credentials"
    t.integer  "user_id"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "provider",    limit: 255
    t.string   "history_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string   "name"
    t.text     "rules"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "message_id_mappings", force: :cascade do |t|
    t.string   "email_message_id"
    t.integer  "account_link_id"
    t.string   "provider_message_id"
    t.string   "provider_thread_id"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
  end

  add_index "message_id_mappings", ["account_link_id"], name: "index_message_id_mappings_on_account_link_id"
  add_index "message_id_mappings", ["email_message_id"], name: "index_message_id_mappings_on_email_message_id"

  create_table "thread_id_mappings", force: :cascade do |t|
    t.integer  "from_account_link_id"
    t.string   "from_thread_id"
    t.integer  "to_account_link_id"
    t.string   "to_thread_id"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true

end
