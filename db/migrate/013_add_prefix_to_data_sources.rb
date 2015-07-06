class AddPrefixToDataSources < ActiveRecord::Migration
  def self.up
    add_column :data_sources, :prefix, :string
  end

  def self.down
    remove_column :data_sources, :prefix
  end
end
