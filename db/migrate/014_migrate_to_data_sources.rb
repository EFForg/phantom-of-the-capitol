class MigrateToDataSources < ActiveRecord::Migration
  def self.up
    puts "Please enter the *full* path to your contact congress repository, or leave blank if N/A: "
    cc_repo = $stdin.gets.strip
    return if cc_repo.blank?

    cc_commit = Application.contact_congress_commit
    DataSource.create(name: 'congress', path: cc_repo, yaml_subpath: 'members/', latest_commit: cc_commit, prefix: "")
  end

  def self.down
    DataSource.find_by_name('congress').destroy
  end
end
