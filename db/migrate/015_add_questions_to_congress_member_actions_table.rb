class AddQuestionsToCongressMemberActionsTable < ActiveRecord::Migration
  def self.up
    add_column :congress_member_actions, :question_selector, :string
    add_column :congress_member_actions, :answer_selector, :string
    add_column :congress_member_actions, :pairs, :text
  end

  def self.down
    remove_column :congress_member_actions, :question_selector
    remove_column :congress_member_actions, :answer_selector
    remove_column :congress_member_actions, :pairs
  end
end
