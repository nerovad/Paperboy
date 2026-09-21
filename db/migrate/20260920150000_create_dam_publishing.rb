# frozen_string_literal: true

# Where the library can send a finished asset, and the record of each sending.
#
# A target is an account on somewhere that publishes video and pictures —
# YouTube, Vimeo, Instagram, Facebook, TikTok — or a URL of our own. A
# publication is one asset going to one of them, kept afterwards whatever the
# outcome, because "did that ever go up, and where is it" is the question the
# screen exists to answer.
class CreateDamPublishing < ActiveRecord::Migration[8.0]
  def change
    create_publish_targets
    create_publications
  end

  private

  def create_publish_targets
    create_table :dam_publish_targets do |t|
      t.string :key, null: false
      t.string :label, null: false
      # youtube | vimeo | instagram | facebook | tiktok | http
      t.string :provider, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :position, null: false, default: 0
      t.text :notes

      # The account inside the provider: a YouTube channel, a Facebook page,
      # an Instagram business account. Blank means "whatever the token is for".
      t.string :account_ref
      t.string :account_label

      # A custom HTTP endpoint, and nothing else, uses these.
      t.string :endpoint_url
      t.string :http_method, null: false, default: 'POST'
      t.text :headers, comment: 'One "Name: value" per line'
      # multipart | json — whether the file rides in the body or is fetched
      # by the far end from the link we hand it.
      t.string :body_style, null: false, default: 'multipart'
      t.string :file_field, null: false, default: 'file'

      t.string :default_privacy

      # Tokens, never readable from the database on their own. The client id
      # and secret they were issued against stay in .env, per host.
      t.text :oauth_access_token
      t.text :oauth_refresh_token
      t.datetime :oauth_expires_at
      t.string :oauth_scope
      t.datetime :connected_at
      t.string :connected_by_id
      t.string :connected_by_name
      t.datetime :last_published_at

      t.timestamps
    end

    add_index :dam_publish_targets, :key, unique: true
    add_index :dam_publish_targets, :provider
    add_index :dam_publish_targets, :enabled
  end

  def create_publications
    create_table :dam_publications do |t|
      t.references :asset, null: false, foreign_key: { to_table: :dam_assets }
      t.references :publish_target, null: false, foreign_key: { to_table: :dam_publish_targets }
      # Copied rather than read through the association, so a publication of a
      # since-deleted target still says where it went.
      t.string :asset_title
      t.string :target_label
      t.string :provider

      # queued | running | succeeded | failed | cancelled
      t.string :status, null: false, default: 'queued'

      t.string :title
      t.text :description
      t.string :tags
      t.string :privacy

      t.string :external_id
      t.string :external_url
      t.integer :response_code
      t.text :error
      t.text :log
      t.integer :attempts, null: false, default: 0

      # The Jobs feed entry this publication raised, so one row can be read
      # from either screen.
      t.integer :job_id

      # Lets a provider that will only fetch from a link — Instagram — reach
      # the bytes while the publish is in flight, and never after.
      t.string :public_token

      t.string :requested_by_id
      t.string :requested_by_name
      t.datetime :queued_at
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :dam_publications, :status
    add_index :dam_publications, :created_at
    add_index :dam_publications, :requested_by_id
    add_index :dam_publications, :public_token, unique: true, where: '([public_token] IS NOT NULL)'
  end
end
