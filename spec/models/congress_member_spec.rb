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

    it "should successfully fill form for a congress member via CongressMember.fill_out_form_with_capybara" do
      expect(@congress_member.fill_out_form_with_capybara(MOCK_VALUES)[:success]).to be_truthy
    end

    it "should not increase the number of open files drastically after calls to CongressMember.fill_out_form_with_capybara" do
      before_of = %x(lsof -p #{Process.pid} | wc -l).strip.to_i
      @of_iterations.times do
        @congress_member.fill_out_form_with_capybara(MOCK_VALUES)
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

  describe "#fill_out_form_with_capybara (poltergeist)" do
    let(:session){ Capybara::Session.new(:poltergeist) }
    let(:congress_member){ create :congress_member }
    let(:fields) { MOCK_VALUES }

    context "has action: visit" do
      let(:action) { CongressMemberAction.new(action: "visit", value: "https://example.com/") }
      before { congress_member.actions << action }
      it "should " do
        expect(session).to receive(:visit).with(action.value)
        congress_member.fill_out_form_with_capybara(fields, session)
      end
    end

    context "has action: wait" do
      let(:action) { CongressMemberAction.new(action: "wait", value: "123") }
      before { congress_member.actions << action }
      it "should " do
        expect_any_instance_of(CongressMemberAction).to receive(:sleep).with(action.value.to_i)
        congress_member.fill_out_form_with_capybara(fields, session)
      end
    end

    context "has action: fill_in" do
      let(:action) { CongressMemberAction.new(action: "fill_in", selector: ".abc .xyz") }
      before { congress_member.actions << action }

      context "action value is a placeholder" do
        before { action.update(value: "$NAME_FIRST") }
        it "should find an element by selector and fill in the user provided value" do
          html_node = double
          expect(session).to receive(:find).with(action.selector){ html_node }
          expect(html_node).to receive(:set).with(fields["$NAME_FIRST"])
          congress_member.fill_out_form_with_capybara(fields, session)
        end

        pending "should respect max_length options"
      end

      context "action value is not a placeholder" do
        before { action.update(value: "a form input value") }
        it "should find an element by selector and fill in the given value" do
          html_node = double
          expect(session).to receive(:find).with(action.selector){ html_node }
          expect(html_node).to receive(:set).with(action.value)
          congress_member.fill_out_form_with_capybara(fields, session)
        end
      end
    end

    context "has action: select" do
      let(:action) { CongressMemberAction.new(action: "select", selector: ".abc .xyz") }
      before { congress_member.actions << action }

      before do
        expect(session).to receive(:within) do |selector, &block|
          expect(selector).to eq(action.selector)
          block.call
        end
      end

      context "action value is not a placeholder" do
        before { action.update(value: "aFormOptionValue") }
        it "should lookup the <option> node with the given value and select it" do
          html_node = double
          expect(session).to receive(:find).with(%(option[value="#{action.value}"])){ html_node }
          expect(html_node).to receive(:select_option)
          congress_member.fill_out_form_with_capybara(fields, session)
        end

        pending "multiple options with the given value exist"
        pending "no option with the given value exists" # should then search as if value is regex
      end

      context "action value is a placeholder" do
        before { action.update(value: "$TOPIC") }
        it "should lookup the <option> node with the user provided value and select it" do
          html_node = double
          expect(session).to receive(:find).with(%(option[value="#{fields[action.value]}"])){ html_node }
          expect(html_node).to receive(:select_option)
          congress_member.fill_out_form_with_capybara(fields, session)
        end

        pending "multiple options with the given user provided value exist"
        pending "no option with the given user provided value exists" # should then search as if value is regex
      end

      context "action selector does not match document" do
        pending "should result in { success: false } unless DEPENDENT option is present"
      end
    end

    context "has action: click_on" do
      let(:action) { CongressMemberAction.new(action: "click_on", selector: ".abc .xyz") }
      before { congress_member.actions << action }
      it "should find an element using the action's selector and click on it" do
        html_node = double
        expect(session).to receive(:find).with(action.selector){ html_node }
        expect(html_node).to receive(:click)
        congress_member.fill_out_form_with_capybara(fields, session)
      end
    end

    context "has action: find" do
      let(:action) { CongressMemberAction.new(action: "find", selector: ".abc .xyz") }
      before { congress_member.actions << action }

      context "action value is nil" do
        it "should find an element using the action's selector" do
          expect(session).to receive(:find).with(action.selector, wait: CongressMemberAction::DEFAULT_FIND_WAIT_TIME)
          congress_member.fill_out_form_with_capybara(fields, session)
        end
      end

      context "action value is not nil" do
        before { action.update(value: "the action value") }
        it "should find an element using the action's selector and text content matching the action's value" do
          regexp = double
          expect(Regexp).to receive(:compile).with(action.value){ regexp }
          expect(session).to receive(:find).with(action.selector,
                                                 text: regexp,
                                                 wait: CongressMemberAction::DEFAULT_FIND_WAIT_TIME)
          congress_member.fill_out_form_with_capybara(fields, session)
        end
      end

      pending "should respect wait time option"
    end

    context "has action: check" do
      let(:action) { CongressMemberAction.new(action: "check", selector: ".abc .xyz") }
      before { congress_member.actions << action }
      it "should find an element using the action's selector and check it" do
        html_node = double
        expect(session).to receive(:find).with(action.selector){ html_node }
        expect(html_node).to receive(:set).with(true)
        congress_member.fill_out_form_with_capybara(fields, session)
      end
    end

    context "has action: uncheck" do
      let(:action) { CongressMemberAction.new(action: "uncheck", selector: ".abc .xyz") }
      before { congress_member.actions << action }
      it "should find an element using the action's selector and un-check it" do
        html_node = double
        expect(session).to receive(:find).with(action.selector){ html_node }
        expect(html_node).to receive(:set).with(false)
        congress_member.fill_out_form_with_capybara(fields, session)
      end
    end

    context "has action: choose" do
      let(:action) { CongressMemberAction.new(action: "choose", selector: ".abc .xyz") }
      before { congress_member.actions << action }

      context "action.options is nil" do
        it "should find an element using the action's selector and select it" do
          html_node = double
          expect(session).to receive(:find).with(action.selector){ html_node }
          expect(html_node).to receive(:set).with(true)
          congress_member.fill_out_form_with_capybara(fields, session)
        end
      end

      context "action.options is not nil" do
        before { action.update(options: { not_nil: true }, value: "$NAME_FIRST") }
        it "should find an element using the action's selector and user provided value and select it" do
          html_node = double
          selector = %(#{action.selector}[value="#{fields[action.value]}"])
          expect(session).to receive(:find).with(selector){ html_node }
          expect(html_node).to receive(:set).with(true)
          congress_member.fill_out_form_with_capybara(fields, session)
        end
      end
    end

    context "has action: javascript" do
      let(:action) { CongressMemberAction.new(action: "javascript", value: "someJavaScript();") }
      before { congress_member.actions << action }
      it "should evaluate the action's value as javascript" do
        expect(session.driver).to receive(:evaluate_script).with(action.value)
        congress_member.fill_out_form_with_capybara(fields, session)
      end
    end
  end
end
