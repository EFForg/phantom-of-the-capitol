class CreateApplicationSettings < ActiveRecord::Migration
  def self.up
    create_table :application_settings do |t|
      t.string :key
      t.text :value

      t.timestamps
    end
    add_index :application_settings, :key, :unique => true
  end

  def self.down
    drop_table :application_settings
  end
end
