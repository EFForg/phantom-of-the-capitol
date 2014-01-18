require File.dirname(__FILE__) + '/../spec_helper.rb'

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
