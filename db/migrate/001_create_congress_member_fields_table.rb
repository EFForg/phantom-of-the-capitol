class CreateCongressMemberFieldsTable < ActiveRecord::Migration
  def self.up
    create_table :congress_member_fields do |t|
      t.integer :step
      t.string  :field_type
      t.string  :name
      t.string  :selector
      t.string  :value
      t.boolean :required, :default => false
      t.text    :options
    end
  end

  def self.down
    drop_table :congress_member_fields
  end
end
