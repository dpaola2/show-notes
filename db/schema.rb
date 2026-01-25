# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_25_143629) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "episodes", force: :cascade do |t|
    t.string "audio_url"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "duration_seconds"
    t.string "guid"
    t.bigint "podcast_id", null: false
    t.datetime "published_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["guid"], name: "index_episodes_on_guid", unique: true
    t.index ["podcast_id"], name: "index_episodes_on_podcast_id"
  end

  create_table "podcasts", force: :cascade do |t|
    t.string "artwork_url"
    t.string "author"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "feed_url"
    t.string "guid"
    t.datetime "last_fetched_at"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["guid"], name: "index_podcasts_on_guid", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "podcast_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["podcast_id"], name: "index_subscriptions_on_podcast_id"
    t.index ["user_id", "podcast_id"], name: "index_subscriptions_on_user_id_and_podcast_id", unique: true
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "summaries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "episode_id", null: false
    t.jsonb "quotes"
    t.text "searchable_text"
    t.jsonb "sections"
    t.datetime "updated_at", null: false
    t.index ["episode_id"], name: "index_summaries_on_episode_id"
  end

  create_table "transcripts", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "episode_id", null: false
    t.datetime "updated_at", null: false
    t.index ["episode_id"], name: "index_transcripts_on_episode_id"
  end

  create_table "user_episodes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "episode_id", null: false
    t.integer "location", default: 0, null: false
    t.text "processing_error"
    t.integer "processing_status", default: 0, null: false
    t.datetime "trashed_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["episode_id"], name: "index_user_episodes_on_episode_id"
    t.index ["user_id", "episode_id"], name: "index_user_episodes_on_user_id_and_episode_id", unique: true
    t.index ["user_id"], name: "index_user_episodes_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "magic_token"
    t.datetime "magic_token_expires_at"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "episodes", "podcasts"
  add_foreign_key "subscriptions", "podcasts"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "summaries", "episodes"
  add_foreign_key "transcripts", "episodes"
  add_foreign_key "user_episodes", "episodes"
  add_foreign_key "user_episodes", "users"
end
