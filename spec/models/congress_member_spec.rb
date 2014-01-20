require 'spec_helper'

describe CongressMember do
  describe "that already exists" do
    before do
      @congress_member = create :congress_member, :bioguide_id => "B010101"
    end

    it "should find the congress member based on bioguide id with CongressMember.bioguide" do
      expect(CongressMember.bioguide("B010101")).not_to be_nil
      expect(CongressMember.bioguide("B010101")).to eq(@congress_member)
    end

    it "should modify the existing congress member based on bioguide id via CongressMember.with_existing_bioguide" do
      CongressMember.with_existing_bioguide("B010101") do |c|
        expect(@congress_member.bioguide_id).to eq("B010101")
        c.bioguide_id = "C010101"
        c.save
      end

      @congress_member.reload
      expect(@congress_member.bioguide_id).to eq("C010101")
    end

    it "should modify the existing congress member based on bioguide id via CongressMember.with_new_or_existing_bioguide" do
      CongressMember.with_new_or_existing_bioguide("B010101") do |c|
        expect(@congress_member.bioguide_id).to eq("B010101")
        c.bioguide_id = "C010101"
        c.save
      end

      @congress_member.reload
      expect(@congress_member.bioguide_id).to eq("C010101")
    end

    describe "that has actions" do
      before do
        create :congress_member_action, :action => "visit", :value => "http://localhost:3001/", :step => 1, :congress_member => @congress_member
        create :congress_member_action, :action => "fill_in", :name => 'zip', :selector => '#zip', :value => "$ADDRESS_ZIP5", :required => true, :step => 2, :congress_member => @congress_member    
        create :congress_member_action, :action => "find", :selector => '#first-name', :step => 3, :congress_member => @congress_member
        create :congress_member_action, :action => "fill_in", :name => 'first-name', :selector => '#first-name', :value => "$NAME_FIRST", :required => true, :step => 4, :congress_member => @congress_member
        create :congress_member_action, :action => "fill_in", :name => 'last-name', :selector => '#last-name', :value => "$NAME_LAST", :required => true, :step => 5, :congress_member => @congress_member
        create :congress_member_action, :action => "fill_in", :name => 'address', :selector => '#address', :value => "$ADDRESS_STREET", :required => true, :step => 6, :congress_member => @congress_member
        create :congress_member_action, :action => "fill_in", :name => 'city', :selector => '#city', :value => "$ADDRESS_CITY", :required => true, :step => 7, :congress_member => @congress_member
        create :congress_member_action, :action => "fill_in", :name => 'email', :selector => '#email', :value => "$EMAIL", :required => true, :step => 8, :congress_member => @congress_member
        create :congress_member_action, :action => "check", :name => 'email-opt-in', :selector => '#email-opt-in', :step => 9, :congress_member => @congress_member
        create :congress_member_action, :action => "uncheck", :name => 'email-opt-out', :selector => '#email-opt-out', :step => 10, :congress_member => @congress_member
        create :congress_member_action, :action => "choose", :name => 'favorite-color', :selector => 'input[name=favorite-color][value=green]', :step => 11, :congress_member => @congress_member
        create :congress_member_action, :action => "fill_in", :name => 'message', :selector => '#message', :value => "$MESSAGE", :required => true, :step => 12, :congress_member => @congress_member
        create :congress_member_action, :action => "select", :name => 'prefix', :selector => '#prefix', :value => "$NAME_PREFIX", :required => true, :step => 13, :congress_member => @congress_member
        create :congress_member_action, :action => "click_on", :selector => 'input[type=submit]', :value => "send", :step => 14, :congress_member => @congress_member
      end

      it "should successfully fill form for a congress member via CongressMember.fill_out_form" do
        expect(@congress_member.fill_out_form(
          "$NAME_FIRST" => "John",
          "$NAME_LAST" => "Doe",
          "$ADDRESS_STREET" => "123 Main Street",
          "$ADDRESS_CITY" => "New York",
          "$ADDRESS_ZIP5" => "10112",
          "$EMAIL" => "joe@example.com",
          "$MESSAGE" => "I have concerns about the proposal....",
          "$NAME_PREFIX" => "Grand Moff"
        )).to be_true
      end
    end
  end

  it "should create a new congress member with bioguide id via CongressMember.with_new_bioguide" do
    CongressMember.with_new_bioguide("D010101") do |c|
      expect(c.bioguide_id).to eq("D010101")
      c.success_criteria = "something"
      c.save
    end
    
    expect(CongressMember.find_by_bioguide_id("D010101")).not_to be_nil
  end

  it "should create a new congress member with bioguide id via CongressMember.with_new_or_existing_bioguide" do
    CongressMember.with_new_or_existing_bioguide("D010101") do |c|
      expect(c.bioguide_id).to eq("D010101")
      c.success_criteria = "something"
      c.save
    end
    
    expect(CongressMember.find_by_bioguide_id("D010101")).not_to be_nil
  end

end
