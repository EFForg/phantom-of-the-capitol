class DropApplicationSettings < ActiveRecord::Migration
  def self.up
    drop_table :application_settings
  end

  def self.down
    create_table :application_settings do |t|
      t.string :key
      t.text :value

      t.timestamps
    end
    add_index :application_settings, :key, :unique => true
  end
end
