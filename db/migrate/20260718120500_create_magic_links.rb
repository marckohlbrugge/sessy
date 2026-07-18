class CreateMagicLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :magic_links do |t|
      t.references :user, null: false, foreign_key: true
      t.string :code, null: false
      t.datetime :expires_at, null: false
      t.integer :purpose, null: false, default: 0

      t.timestamps
    end

    add_index :magic_links, :code, unique: true
  end
end
