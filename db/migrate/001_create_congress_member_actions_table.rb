class CreateCongressMemberActionsTable < ActiveRecord::Migration
  def self.up
    create_table :congress_member_actions do |t|
      t.integer  :congress_member_id
      t.integer :step
      t.string  :action
      t.string  :name
      t.string  :selector
      t.string  :value
      t.boolean :required, :default => false
      t.integer :maxlength
      t.string  :captcha_selector 
      t.string  :captcha_id_selector 
      t.text    :options
    end
  end

  def self.down
    drop_table :congress_member_actions
  end
end
