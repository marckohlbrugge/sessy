class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false, index: { unique: true }
      t.string :token_prefix, null: false
      t.datetime :last_used_at

      t.timestamps
    end
  end
end
