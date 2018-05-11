require 'spec_helper'

describe FormFiller do
  let(:iterations) { 10 }
  let(:congress_member) do
    create :congress_member_with_actions, :bioguide_id => "B010101"
  end
  let(:campaign_tag) { "" }

  subject(:fill_out_form) do
    described_class.new(congress_member, MOCK_VALUES, campaign_tag).fill_out_form
  end

  it "should successfully fill form for a congress member" do
    expect(fill_out_form).to be_truthy
  end

  it "should not increase the number of open files drastically" do
    before_of = %x(lsof -p #{Process.pid} | wc -l).strip.to_i
    iterations.times { fill_out_form }
    after_of = %x(lsof -p #{Process.pid} | wc -l).strip.to_i
    expect(after_of).to be < (before_of + iterations)
  end

  it "should add a success record to the FillStatus table" do
    fill_out_form
    expect(FillStatus.success.count).to eq(1)
  end

  context "when campaign tag is provided" do
    let(:campaign_tag) { "some campaign" }

    it "should succeed" do
      expect(fill_out_form).to be_truthy
    end

    it "should create a new tag" do
      expect { fill_out_form }.to change(CampaignTag, :count).by(1)
      expect(CampaignTag.last.name).to eq(campaign_tag)
    end
  end

  context "with a delay" do
    subject(:delay_fill) do
      described_class.new(congress_member, MOCK_VALUES).delay.fill_out_form
    end

    it "should delay filling out a form for a congress member" do
      delay_fill
      expect(Delayed::Worker.new.run Delayed::Job.last).to be_truthy
    end

    it "should not update the FillStatus table" do
      expect { delay_fill }
        .not_to change(FillStatus, :count)
    end
  end

  context "with an incorrect success criteria" do
    let(:congress_member) do
      create(
        :congress_member_with_actions,
        success_criteria: YAML.dump(
          {"headers"=>{"status"=>200}, "body"=>{"contains"=>"Won't get me!"}}
        )
      )
    end

    it "should return a failed FilledStatus" do
      expect(fill_out_form.success?).to be false
    end

    it "should add a failure record to the FillStatus table" do
      fill_out_form
      expect(FillStatus.failure.count).to eq(1)
    end

    it "should include a screenshot in the FillStatus" do
      fill_out_form
      expect(YAML.load(FillStatus.last.extra).include? :screenshot).to eq(true)
    end
  end

  describe "with saved session and action" do
    let(:session){ Capybara::Session.new(:poltergeist) }
    let(:congress_member){ create :congress_member }
    let(:fields) { MOCK_VALUES }

    subject(:fill_out_form) do
      described_class.new(congress_member, fields, campaign_tag, session: session)
        .fill_out_form(action)
    end

    before { congress_member.actions << action }

    context "has action: visit" do
      let(:action) do
        CongressMemberAction.new(action: "visit", value: "https://example.com/")
      end

      it "visits the session" do
        expect(session).to receive(:visit).with(action.value)
        fill_out_form
      end
    end

    context "has action: wait" do
      let(:action) { CongressMemberAction.new(action: "wait", value: "123") }

      it "waits" do
        expect_any_instance_of(CongressMemberAction)
          .to receive(:sleep).with(action.value.to_i)
        fill_out_form
      end
    end

    context "has action: fill_in" do
      let(:action) do
        CongressMemberAction.new(action: "fill_in", selector: ".abc .xyz")
      end

      context "action value is a placeholder" do
        before { action.update(value: "$NAME_FIRST") }

        it "should find an element by selector and fill in the user provided value" do
          html_node = double
          expect(session).to receive(:find).with(action.selector){ html_node }
          expect(html_node).to receive(:set).with(fields["$NAME_FIRST"])
          fill_out_form
        end

        pending "should respect max_length options"
      end

      context "action value is not a placeholder" do
        before { action.update(value: "a form input value") }

        it "should find an element by selector and fill in the given value" do
          html_node = double
          expect(session).to receive(:find).with(action.selector){ html_node }
          expect(html_node).to receive(:set).with(action.value)
          fill_out_form
        end
      end
    end

    context "has action: select" do
      # TODO: this is pretty brittle.  Move it into a feature spec and stop stubbing.
      let(:action) do
        CongressMemberAction.new(action: "select", selector: ".abc .xyz")
      end

      before do
        expect(session).to receive(:within) do |selector, &block|
          expect(selector).to eq(action.selector)
          block.call
        end
      end

      context "action value is not a placeholder" do
        # TODO: this case should include multiple options with the given value
        before { action.update(value: "aFormOptionValue") }

        it "should lookup the <option> node with the given value and select it" do
          html_node = double
          expect(session).to receive(:first).with(%(option[value="#{action.value}"])){ html_node }
          expect(html_node).to receive(:select_option)
          fill_out_form
        end

        pending "no option with the given value exists" # should then search as if value is regex
      end

      context "action value is a placeholder" do
        # TODO: this case should include multiple options with the given value
        before { action.update(value: "$TOPIC") }

        it "should lookup the <option> node with the user provided value and select it" do
          html_node = double
          expect(session).to receive(:first).with(%(option[value="#{fields[action.value]}"])){ html_node }
          expect(html_node).to receive(:select_option)
          fill_out_form
        end

        # should then search as if value is regex
        pending "no option with the given user provided value exists"
      end

      context "action selector does not match document" do
        pending "should result in { success: false } unless DEPENDENT option is present"
      end
    end

    context "has action: click_on" do
      let(:action) do
        CongressMemberAction.new(action: "click_on", selector: ".abc .xyz")
      end

      it "should find an element using the action's selector and click on it" do
        html_node = double
        expect(session).to receive(:find).with(action.selector){ html_node }
        expect(html_node).to receive(:click)
        fill_out_form
      end
    end

    context "has action: find" do
      let(:action) do
        CongressMemberAction.new(action: "find", selector: ".abc .xyz")
      end

      it "should find an element using the action's selector" do
        expect(session).to receive(:find).with(action.selector, wait: CongressMemberAction::DEFAULT_FIND_WAIT_TIME)
        fill_out_form
      end

      context "action value is not nil" do
        before { action.update(value: "the action value") }
        it "should find an element using the action's selector and text content matching the action's value" do
          regexp = double
          expect(Regexp).to receive(:compile).with(action.value){ regexp }
          expect(session).to receive(:find).with(
            action.selector, text: regexp, wait: CongressMemberAction::DEFAULT_FIND_WAIT_TIME
          )
          fill_out_form
        end
      end

      pending "should respect wait time option"
    end

    context "has action: check" do
      let(:action) do
        CongressMemberAction.new(action: "check", selector: ".abc .xyz")
      end

      it "should find an element using the action's selector and check it" do
        html_node = double
        expect(session).to receive(:find).with(action.selector){ html_node }
        expect(html_node).to receive(:set).with(true)
        fill_out_form
      end
    end

    context "has action: uncheck" do
      let(:action) do
        CongressMemberAction.new(action: "uncheck", selector: ".abc .xyz")
      end

      it "should find an element using the action's selector and un-check it" do
        html_node = double
        expect(session).to receive(:find).with(action.selector){ html_node }
        expect(html_node).to receive(:set).with(false)
        fill_out_form
      end
    end

    context "has action: choose" do
      let(:action) do
        CongressMemberAction.new(action: "choose", selector: ".abc .xyz")
      end

      it "should find an element using the action's selector and select it" do
        html_node = double
        expect(session).to receive(:find).with(action.selector){ html_node }
        expect(html_node).to receive(:set).with(true)
        fill_out_form
      end

      context "action.options is not nil" do
        before { action.update(options: { not_nil: true }, value: "$NAME_FIRST") }

        it "should find an element using the action's selector and user provided value and select it" do
          html_node = double
          selector = %(#{action.selector}[value="#{fields[action.value]}"])
          expect(session).to receive(:find).with(selector){ html_node }
          expect(html_node).to receive(:set).with(true)
          fill_out_form
        end
      end
    end

    context "has action: javascript" do
      let(:action) do
        CongressMemberAction.new(action: "javascript", value: "someJavaScript();")
      end

      it "should evaluate the action's value as javascript" do
        expect(session.driver).to receive(:evaluate_script).with(action.value)
        fill_out_form
      end
    end
  end

  describe "with unfulfillable actions" do
    let(:congress_member) { create :congress_member_with_actions }
    let!(:action) do
      create(:congress_member_action,
             action: "fill_in",
             name: 'middle-name',
             selector: '#middle-name',
             value: "$NAME_MIDDLE",
             required: true, step: 4,
             congress_member: congress_member)
    end
    subject(:fill_out_form) do
      described_class.new(
        congress_member, MOCK_VALUES.merge({"$NAME_MIDDLE" => "Bart"})
      ).fill_out_form(action)
    end

    it "should return a failed FillStatus" do
      expect(fill_out_form.success?).to be false
    end

    it "should add an error record to the FillStatus table" do
      fill_out_form
      expect(FillStatus.error.count).to eq(1)
    end

    it "should include a screenshot in the FillStatus" do
      fill_out_form
      expect(YAML.load(FillStatus.last.extra).include? :screenshot).to eq(true)
    end
  end

  describe "with captcha" do
    let(:congress_member) do
      create :congress_member_with_actions_and_captcha, :bioguide_id => "B010101"
    end

    it "should succeed" do
      expect(fill_out_form { |c| "placeholder" }).to be_truthy
    end
  end
end
