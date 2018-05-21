require 'spec_helper'

describe FormFiller::Capybara do
  let(:iterations) { 10 }
  let(:congress_member) do
    create :congress_member_with_actions, :bioguide_id => "B010101"
  end
  let(:campaign_tag) { "" }

  subject(:fill_out) do
    described_class.new(congress_member, MOCK_VALUES, campaign_tag).fill_out
  end

  describe "with saved session and action" do
    let(:session){ Capybara::Session.new(:headless_chrome) }
    let(:congress_member){ create :congress_member }
    let(:fields) { MOCK_VALUES }

    subject(:fill_out) do
      described_class.new(congress_member, fields, session: session)
        .fill_out(action)
    end

    before { congress_member.actions << action }

    context "has action: visit" do
      let(:action) do
        CongressMemberAction.new(action: "visit", value: "https://example.com/")
      end

      it "visits the session" do
        expect(session).to receive(:visit).with(action.value)
        fill_out
      end
    end

    context "has action: wait" do
      let(:action) { CongressMemberAction.new(action: "wait", value: "123") }

      it "waits" do
        expect_any_instance_of(CongressMemberAction)
          .to receive(:sleep).with(action.value.to_i)
        fill_out
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
          fill_out
        end

        pending "should respect max_length options"
      end

      context "action value is not a placeholder" do
        before { action.update(value: "a form input value") }

        it "should find an element by selector and fill in the given value" do
          html_node = double
          expect(session).to receive(:find).with(action.selector){ html_node }
          expect(html_node).to receive(:set).with(action.value)
          fill_out
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
          fill_out
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
          fill_out
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
        fill_out
      end
    end

    context "has action: find" do
      let(:action) do
        CongressMemberAction.new(action: "find", selector: ".abc .xyz")
      end

      it "should find an element using the action's selector" do
        expect(session).to receive(:find).with(action.selector, wait: CongressMemberAction::DEFAULT_FIND_WAIT_TIME)
        fill_out
      end

      context "action value is not nil" do
        before { action.update(value: "the action value") }
        it "should find an element using the action's selector and text content matching the action's value" do
          regexp = double
          expect(Regexp).to receive(:compile).with(action.value){ regexp }
          expect(session).to receive(:find).with(
            action.selector, text: regexp, wait: CongressMemberAction::DEFAULT_FIND_WAIT_TIME
          )
          fill_out
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
        fill_out
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
        fill_out
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
        fill_out
      end

      context "action.options is not nil" do
        before { action.update(options: { not_nil: true }, value: "$NAME_FIRST") }

        it "should find an element using the action's selector and user provided value and select it" do
          html_node = double
          selector = %(#{action.selector}[value="#{fields[action.value]}"])
          expect(session).to receive(:find).with(selector){ html_node }
          expect(html_node).to receive(:set).with(true)
          fill_out
        end
      end
    end

    context "has action: javascript" do
      let(:action) do
        CongressMemberAction.new(action: "javascript", value: "someJavaScript();")
      end

      it "should evaluate the action's value as javascript" do
        expect(session.driver).to receive(:evaluate_script).with(action.value)
        fill_out
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
    subject(:fill_out) do
      described_class.new(
        congress_member, MOCK_VALUES.merge({"$NAME_MIDDLE" => "Bart"})
      ).fill_out(action)
    end

    it "should return a failed FillStatus" do
      expect(fill_out.success?).to be false
    end

    it "should add an error record to the FillStatus table" do
      fill_out
      expect(FillStatus.error.count).to eq(1)
    end

    it "should include a screenshot in the FillStatus" do
      fill_out
      expect(YAML.load(FillStatus.last.extra).include? :screenshot).to eq(true)
    end
  end
end
