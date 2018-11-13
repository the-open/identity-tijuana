class CreateTijuanaTestDb < ActiveRecord::Migration[5.0]
  def up
    create_table 'tags', force: :cascade do |t|
      t.string  'name',           limit: 255
      t.integer 'taggings_count', limit: 4, default: 0
    end

    add_index 'tags', ['name'], name: 'index_tags_on_name', unique: true, using: :btree

    create_table 'taggings', force: :cascade do |t|
      t.integer  'tag_id',        limit: 4
      t.integer  'taggable_id',   limit: 4
      t.string   'taggable_type', limit: 255
      t.integer  'tagger_id',     limit: 4
      t.string   'tagger_type',   limit: 255
      t.string   'context',       limit: 128
      t.datetime 'created_at'
    end

    add_index 'taggings', %w[tag_id taggable_id taggable_type context], name: 'taggind_idx', unique: true, using: :btree
    add_index 'taggings', %w[taggable_id taggable_type tag_id], name: 'tags_list_cutter_idx', using: :btree

    create_table 'users', force: :cascade do |t|
      t.string   'email',                        limit: 256, null: false
      t.string   'first_name',                   limit: 64
      t.string   'last_name',                    limit: 64
      t.string   'mobile_number',                limit: 32
      t.string   'last_name',                    limit: 64
      t.string   'mobile_number',                limit: 32
      t.string   'home_number',                  limit: 32
      t.string   'street_address',               limit: 128
      t.string   'suburb',                       limit: 64
      t.string   'country_iso',                  limit: 2
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.boolean  'is_member', default: true, null: false
      t.boolean  'do_not_call', default: false, null: false
      t.string   'encrypted_password',           limit: 255
      t.string   'password_salt',                limit: 255
      t.string   'reset_password_token',         limit: 255
      t.datetime 'remember_created_at'
      t.integer  'sign_in_count', limit: 4, default: 0
      t.datetime 'current_sign_in_at'
      t.datetime 'last_sign_in_at'
      t.string   'current_sign_in_ip',           limit: 255
      t.string   'last_sign_in_ip',              limit: 255
      t.boolean  'is_admin', default: false
      t.datetime 'deleted_at'
      t.string   'created_by',                   limit: 255
      t.string   'updated_by',                   limit: 255
      t.integer  'postcode_id',                  limit: 4
      t.string   'old_tags',                     limit: 3072,  default: '',    null: false
      t.string   'new_tags',                     limit: 512,   default: '',    null: false
      t.boolean  'is_volunteer',                               default: false
      t.float    'random',                       limit: 24
      t.string   'fragment',                     limit: 255
      t.boolean  'is_agra_member', default: true
      t.datetime 'reset_password_sent_at'
      t.text     'notes',                        limit: 65_535
      t.string   'quick_donate_trigger_id',      limit: 255
      t.boolean  'low_volume', default: false
      t.datetime 'address_validated_at'
      t.string   'facebook_id',                  limit: 50
      t.string   'otp_secret_key',               limit: 255
      t.integer  'second_factor_attempts_count', limit: 4, default: 0
    end

    add_index 'users', ['created_at'], name: 'created_at_idx', using: :btree
    add_index 'users', %w[deleted_at first_name], name: 'index_users_on_deleted_at_and_first_name', using: :btree
    add_index 'users', %w[deleted_at is_member], name: 'member_status', using: :btree
    add_index 'users', %w[deleted_at last_name], name: 'index_users_on_deleted_at_and_last_name', using: :btree
    add_index 'users', %w[deleted_at notes], name: 'index_users_on_deleted_at_and_notes', length: { 'deleted_at' => nil, 'notes' => 200 }, using: :btree
    add_index 'users', %w[deleted_at postcode_id], name: 'postcode_id_idx', using: :btree
    add_index 'users', %w[deleted_at suburb], name: 'index_users_on_deleted_at_and_suburb', using: :btree
    add_index 'users', ['email'], name: 'index_users_on_email', unique: true, length: { 'email' => 255 }, using: :btree
    add_index 'users', ['otp_secret_key'], name: 'index_users_on_otp_secret_key', unique: true, using: :btree
    add_index 'users', ['random'], name: 'users_random_idx', using: :btree
    add_index 'users', ['reset_password_token'], name: 'users_reset_password_token_idx', using: :btree
    add_index 'users', ['do_not_call'], name: 'index_users_on_do_not_call', using: :btree

    create_table 'postcodes', force: :cascade do |t|
      t.string   'number',     limit: 255
      t.string   'state',      limit: 255
      t.datetime 'created_at'
      t.datetime 'updated_at'
      t.float    'longitude',  limit: 53
      t.float    'latitude',   limit: 53
    end
  end
end
