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
  end

  v = {
    "$NAME_FIRST" => "John",
    "$NAME_LAST" => "Doe",
    "$ADDRESS_STREET" => "123 Main Street",
    "$ADDRESS_CITY" => "New York",
    "$ADDRESS_ZIP5" => "10112",
    "$EMAIL" => "joe@example.com",
    "$MESSAGE" => "I have concerns about the proposal....",
    "$NAME_PREFIX" => "Grand Moff"
  }

  describe "that already exists with actions" do
    before do
      @congress_member = create :congress_member_with_actions, :bioguide_id => "B010101"
    end

    it "should successfully fill form for a congress member via CongressMember.fill_out_form" do
      expect(@congress_member.fill_out_form(v)).to be_true
    end
  end

  describe "that already exists with actions including captcha" do
    before do
      @congress_member = create :congress_member_with_actions_and_captcha, :bioguide_id => "B010101"
    end


    it "should successfully fill form for a congress member via CongressMember.fill_out_form" do
      @congress_member.fill_out_form(v) do |c|
        "placeholder"
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
