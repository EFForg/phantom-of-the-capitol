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

  describe "that already exists with actions" do
    before do
      @congress_member = create :congress_member_with_actions, :bioguide_id => "B010101"
    end

    it "should successfully fill form for a congress member via CongressMember.fill_out_form" do
      expect(@congress_member.fill_out_form(MOCK_VALUES)).to be_true
    end

    it "should successfully fill form for a congress member via CongressMember.fill_out_form_with_poltergeist" do
      expect(@congress_member.fill_out_form_with_poltergeist(MOCK_VALUES)).to be_true
    end

    it "should successfully fill form for a congress member and create a new tag when one is provided via CongressMember.fill_out_form" do
      @campaign_tag = "some campaign"
      expect(@congress_member.fill_out_form(MOCK_VALUES, @campaign_tag)).to be_true
      expect(CampaignTag.last.name).to eq(@campaign_tag)
    end

    it "should delay filling out a form for a congress member via CongressMember.delay.fill_out_form" do
      @congress_member.delay.fill_out_form(MOCK_VALUES)
      result = Delayed::Worker.new.run Delayed::Job.last
      expect(result).to be_true
    end
  end
  
  describe "that already exists with actions and an incorrect success criteria" do
    before do
      @congress_member = create :congress_member_with_actions, success_criteria: YAML.dump({"headers"=>{"status"=>200}, "body"=>{"contains"=>"Won't get me!"}})
    end

    it "should raise an error filling out a form via CongressMember.fill_out_form" do
      expect { @congress_member.fill_out_form(MOCK_VALUES) }.to raise_error CongressMember::FillError
    end
  end

  describe "that already exists with unfulfillable actions" do
    before do
      @congress_member = create :congress_member_with_actions
      @congress_member.actions.append(create :congress_member_action, action: "fill_in", name: 'middle-name', selector: '#middle-name', value: "$NAME_MIDDLE", required: true, step: 4, congress_member: @congress_member)
    end

    it "should raise an error filling out a form via CongressMember.fill_out_form" do
      expect { @congress_member.fill_out_form MOCK_VALUES.merge({"$NAME_MIDDLE" => "Bart"}) }.to raise_error Watir::Exception::UnknownObjectException
    end

    it "should keep a delayed job that raises an error filling out a form via CongressMember.fill_out_form" do
      @congress_member.delay.fill_out_form(MOCK_VALUES.merge({"$NAME_MIDDLE" => "Bart"}))
      last_job = Delayed::Job.last
      result = Delayed::Worker.new.run last_job
      expect(result).to be_false
      expect { last_job.reload }.not_to raise_error
    end

  end

  describe "that already exists with actions including captcha" do
    before do
      @congress_member = create :congress_member_with_actions_and_captcha, :bioguide_id => "B010101"
    end


    it "should successfully fill form for a congress member via CongressMember.fill_out_form" do
      expect(
        @congress_member.fill_out_form(MOCK_VALUES) do |c|
          "placeholder"
        end
      ).to be_true
    end

    it "should successfully fill form for a congress member via CongressMember.fill_out_form_with_poltergeist" do
      expect(
        @congress_member.fill_out_form_with_poltergeist(MOCK_VALUES) do |c|
          "placeholder"
        end
      ).to be_true
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
