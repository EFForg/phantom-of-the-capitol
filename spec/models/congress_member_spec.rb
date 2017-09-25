require 'spec_helper'

describe CongressMember do
  describe "that already exists with actions" do
    it "should successfully fill form for a congress member via CongressMember.fill_out_form" do
      v = MOCK_VALUES
      cm = CongressMember.new
      r = cm.fill_out_form(v)
      exp = expect(r)
      exp.to be_truthy
    end
  end
end
