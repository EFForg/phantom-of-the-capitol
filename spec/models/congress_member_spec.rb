require 'spec_helper'

describe CongressMember do
  describe "that already exists with actions" do
    it "should successfully fill form for a congress member via CongressMember.fill_out_form" do
      cm = CongressMember.new
      cm.to_s
      cm.fill_out_form(MOCK_VALUES)
    end
  end
end
