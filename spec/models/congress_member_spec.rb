require 'spec_helper'

describe CongressMember do
  describe "that already exists with actions" do
    before do
      @congress_member = create :congress_member_with_actions, :bioguide_id => "B010101"
      @of_iterations = 10
    end

    it "should successfully fill form for a congress member via CongressMember.fill_out_form" do
      v = MOCK_VALUES
      cm = @congress_member
      r = cm.fill_out_form(v)
      exp = expect(r)
      exp.to be_truthy
    end
  end
end
