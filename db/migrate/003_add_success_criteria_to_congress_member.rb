class AddSuccessCriteriaToCongressMember < ActiveRecord::Migration
  def self.up
    add_column :congress_members, :success_criteria, :string
  end

  def self.down
    remove_column :congress_members, :success_criteria
  end
end
