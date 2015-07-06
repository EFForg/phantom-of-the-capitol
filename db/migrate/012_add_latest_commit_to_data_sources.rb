class AddLatestCommitToDataSources < ActiveRecord::Migration
  def self.up
    add_column :data_sources, :latest_commit, :string, length: 40
  end

  def self.down
    remove_column :data_sources, :latest_commit
  end
end
