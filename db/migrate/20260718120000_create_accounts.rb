class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name
      t.datetime :approved_at
      t.integer :retention_days
      t.boolean :instance, default: false, null: false

      t.timestamps
    end

    add_index :accounts, :instance, unique: true, where: "instance"
  end
end
