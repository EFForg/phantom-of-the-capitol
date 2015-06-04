class CreateDataSourcesTable < ActiveRecord::Migration
  def self.up
    create_table :data_sources do |t|
      t.string :name
      t.string :path
      t.string :yaml_subpath
      t.timestamps
    end
    add_index :data_sources, :name
  end

  def self.down
    drop_table :data_sources
  end
end
