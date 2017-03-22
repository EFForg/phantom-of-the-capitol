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

    it "should deserialize the `success_criteria` field successfully using YAML" do
      expect { YAML.load(@congress_member.success_criteria) }.not_to raise_error
    end
  end

  describe "that already exists with actions" do
    before do
      @congress_member = create :congress_member_with_actions, :bioguide_id => "B010101"
      @of_iterations = 10
    end

    it "should successfully fill form for a congress member via CongressMember.fill_out_form" do
      expect(@congress_member.fill_out_form(MOCK_VALUES)).to be_truthy
    end

    it "should successfully fill form for a congress member via CongressMember.fill_out_form_with_poltergeist" do
      expect(@congress_member.fill_out_form_with_poltergeist(MOCK_VALUES)[:success]).to be_truthy
    end

    it "should successfully fill form for a congress member via CongressMember.fill_out_form_with_webkit" do
      expect(@congress_member.fill_out_form_with_webkit(MOCK_VALUES)[:success]).to be_truthy
    end

    it "should not increase the number of open files drastically after calls to CongressMember.fill_out_form_with_poltergeist" do
      before_of = %x(lsof -p #{Process.pid} | wc -l).strip.to_i
      @of_iterations.times do
        @congress_member.fill_out_form_with_poltergeist(MOCK_VALUES)
      end
      after_of = %x(lsof -p #{Process.pid} | wc -l).strip.to_i
      expect(after_of).to be < (before_of + @of_iterations)
    end

    it "should not increase the number of open files drastically after calls to CongressMember.fill_out_form_with_webkit" do
      before_of = %x(lsof -p #{Process.pid} | wc -l).strip.to_i
      @of_iterations.times do
        @congress_member.fill_out_form_with_webkit(MOCK_VALUES)
      end
      after_of = %x(lsof -p #{Process.pid} | wc -l).strip.to_i
      expect(after_of).to be < (before_of + @of_iterations)
    end

    it "should add a success record to the FillStatus table when successfully filling in a form via CongressMember.fill_out_form" do
      @congress_member.fill_out_form(MOCK_VALUES)
      expect(FillStatus.success.count).to eq(1)
    end

    it "should successfully fill form for a congress member and create a new tag when one is provided via CongressMember.fill_out_form" do
      @campaign_tag = "some campaign"
      expect(@congress_member.fill_out_form(MOCK_VALUES, @campaign_tag)).to be_truthy
      expect(CampaignTag.last.name).to eq(@campaign_tag)
    end

    it "should delay filling out a form for a congress member via CongressMember.delay.fill_out_form" do
      @congress_member.delay.fill_out_form(MOCK_VALUES)
      result = Delayed::Worker.new.run Delayed::Job.last
      expect(result).to be_truthy
    end

    it "should not update the FillStatus table when delaying a form fill via CongressMember.delay.fill_out_form" do
      @congress_member.delay.fill_out_form(MOCK_VALUES)
      expect(FillStatus.count).to eq(0)
    end
  end
  
  describe "that already exists with actions and an incorrect success criteria" do
    before do
      @congress_member = create :congress_member_with_actions, success_criteria: YAML.dump({"headers"=>{"status"=>200}, "body"=>{"contains"=>"Won't get me!"}})
    end

    it "should return a failed FilledStatus filling out a form via CongressMember.fill_out_form" do
      expect(@congress_member.fill_out_form(MOCK_VALUES).success?).to be false
    end

    it "should add a failure record to the FillStatus table when filling out a form via CongressMember.fill_out_form" do
      @congress_member.fill_out_form(MOCK_VALUES)
      expect(FillStatus.failure.count).to eq(1)
    end

    it "should include a screenshot in the FillStatus for filling out a form via CongressMember.fill_out_form" do
      @congress_member.fill_out_form(MOCK_VALUES)
      expect(YAML.load(FillStatus.last.extra).include? :screenshot).to eq(true)
    end
  end

  describe "that already exists with unfulfillable actions" do
    before do
      @congress_member = create :congress_member_with_actions
      @congress_member.actions.append(create :congress_member_action, action: "fill_in", name: 'middle-name', selector: '#middle-name', value: "$NAME_MIDDLE", required: true, step: 4, congress_member: @congress_member)
    end

    it "should return a failed FillStatus filling out a form via CongressMember.fill_out_form" do
      expect(@congress_member.fill_out_form(MOCK_VALUES.merge({"$NAME_MIDDLE" => "Bart"})).success?).to be false
    end

    it "should keep a delayed job that raises an error filling out a form via CongressMember.fill_out_form" do
      @congress_member.delay.fill_out_form!(MOCK_VALUES.merge({"$NAME_MIDDLE" => "Bart"}))
      last_job = Delayed::Job.last
      result = Delayed::Worker.new.run last_job

      expect(result).to be false
      expect { last_job.reload }.not_to raise_error
    end

    it "should add an error record to the FillStatus table when filling out a form via CongressMember.fill_out_form" do
      @congress_member.fill_out_form(MOCK_VALUES.merge({"$NAME_MIDDLE" => "Bart"}))
      expect(FillStatus.error.count).to eq(1)
    end

    it "should include a screenshot in the FillStatus for filling out a form via CongressMember.fill_out_form" do
      @congress_member.fill_out_form(MOCK_VALUES.merge({"$NAME_MIDDLE" => "Bart"}))
      expect(YAML.load(FillStatus.last.extra).include? :screenshot).to eq(true)
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
      ).to be_truthy
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
