
require "spec_helper"
require "cwc/message"

describe Cwc::Message do
  def create_message(params)
    Cwc::Message.new.tap do |message|
      message.delivery[:agent] = {
        name: cwc_client_params[:delivery_agent],
        ack_email: cwc_client_params[:delivery_agent_ack_email],
        contact_name: cwc_client_params[:delivery_agent_contact_name],
        contact_email: cwc_client_params[:delivery_agent_contact_email],
        contact_phone: cwc_client_params[:delivery_agent_contact_phone]
      }

      message.delivery[:organization] = params.fetch(:organization, {})
      message.delivery[:campaign_id] = params.fetch(:campaign_id)

      message.recipient.merge!(params.fetch(:recipient))
      message.constituent.merge!(params.fetch(:constituent))
      message.message.merge!(params.fetch(:message))
    end
  end

  def create_doc(params)
    Nokogiri::XML(create_message(params).to_xml)
  end

  describe "#to_xml" do
    it "should return xml conforming to the CWC spec" do
      params = cwc_message_params

      message = create_message(params)
      expect(message).to receive(:delivery_id).and_return("delivery_id")
      expect(message).to receive(:delivery_date).and_return("delivery_date")

      doc = Nokogiri::XML(message.to_xml)

      expect(doc).to have_xpath("CWC/CWCVersion", "2.0")

      expect(doc).to have_xpath("CWC/Delivery/DeliveryId", "delivery_id")
      expect(doc).to have_xpath("CWC/Delivery/DeliveryDate", "delivery_date")
      expect(doc).to have_xpath("CWC/Delivery/DeliveryAgent", "delivery_agent")
      expect(doc).to have_xpath("CWC/Delivery/DeliveryAgentAckEmailAddress", "delivery_agent_ack_email")
      expect(doc).to have_xpath("CWC/Delivery/DeliveryAgentContact/DeliveryAgentContactName", "delivery_agent_contact_name")
      expect(doc).to have_xpath("CWC/Delivery/DeliveryAgentContact/DeliveryAgentContactEmail", "delivery_agent_contact_email")
      expect(doc).to have_xpath("CWC/Delivery/DeliveryAgentContact/DeliveryAgentContactPhone", "delivery_agent_contact_phone")
      expect(doc).to have_xpath("CWC/Delivery/CampaignId", "campaign_id")

      expect(doc).to have_xpath("CWC/Delivery/Organization", "delivery_organization")
      expect(doc).to have_xpath("CWC/Delivery/OrganizationAbout", "delivery_organization_about")
      expect(doc).to have_xpath("CWC/Delivery/OrganizationContact/OrganizationContactName", "delivery_organization_contact_name")
      expect(doc).to have_xpath("CWC/Delivery/OrganizationContact/OrganizationContactEmail", "delivery_organization_contact_email")
      expect(doc).to have_xpath("CWC/Delivery/OrganizationContact/OrganizationContactPhone", "delivery_organization_contact_phone")

      expect(doc).to have_xpath("CWC/Recipient/MemberOffice", "member_office")
      expect(doc).to have_xpath("CWC/Recipient/IsResponseRequested", "Y")
      expect(doc).to have_xpath("CWC/Recipient/NewsletterOptIn", "Y")

      expect(doc).to have_xpath("CWC/Constituent/Prefix", "prefix")
      expect(doc).to have_xpath("CWC/Constituent/FirstName", "first_name")
      expect(doc).to have_xpath("CWC/Constituent/MiddleName", "middle_name")
      expect(doc).to have_xpath("CWC/Constituent/LastName", "last_name")
      expect(doc).to have_xpath("CWC/Constituent/Suffix", "suffix")
      expect(doc).to have_xpath("CWC/Constituent/Title", "title")
      expect(doc).to have_xpath("CWC/Constituent/Organization", "constituent_organization")
      expect(doc).to have_xpath("CWC/Constituent/Address1", "address1")
      expect(doc).to have_xpath("CWC/Constituent/Address2", "address2")
      expect(doc).to have_xpath("CWC/Constituent/Address3", "address3")
      expect(doc).to have_xpath("CWC/Constituent/City", "city")
      expect(doc).to have_xpath("CWC/Constituent/StateAbbreviation", "state_abbreviation")
      expect(doc).to have_xpath("CWC/Constituent/Zip", "zip_code")
      expect(doc).to have_xpath("CWC/Constituent/Phone", "phone")
      expect(doc).to have_xpath("CWC/Constituent/AddressValidation", "Y")
      expect(doc).to have_xpath("CWC/Constituent/Email", "email")
      expect(doc).to have_xpath("CWC/Constituent/EmailValidation", "Y")

      expect(doc).to have_xpath("CWC/Message/Subject", "message_subject")
      expect(doc).to have_xpath("CWC/Message/LibraryOfCongressTopics/LibraryOfCongressTopic[1]", "library_of_congress_topic1")
      expect(doc).to have_xpath("CWC/Message/LibraryOfCongressTopics/LibraryOfCongressTopic[2]", "library_of_congress_topic2")
      expect(doc).to have_xpath("CWC/Message/Bill[1]/BillCongress", "bill_congress")
      expect(doc).to have_xpath("CWC/Message/Bill[1]/BillTypeAbbreviation", "bill_type_abbreviation")
      expect(doc).to have_xpath("CWC/Message/Bill[1]/BillNumber", "bill_number1")
      expect(doc).to have_xpath("CWC/Message/Bill[2]/BillCongress", "bill_congress")
      expect(doc).to have_xpath("CWC/Message/Bill[2]/BillTypeAbbreviation", "bill_type_abbreviation")
      expect(doc).to have_xpath("CWC/Message/Bill[2]/BillNumber", "bill_number2")
      expect(doc).to have_xpath("CWC/Message/ProOrCon", "pro_or_con")
      expect(doc).to have_xpath("CWC/Message/OrganizationStatement", "organization_statement")
      expect(doc).to have_xpath("CWC/Message/ConstituentMessage", "constituent_message")
      expect(doc).to have_xpath("CWC/Message/MoreInfo", "more_info")

      # Test optional fields
      params[:organization].delete(:contact)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Delivery/OrganizationContact")

      params[:organization].delete(:about)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Delivery/OrganizationAbout")

      params.delete(:organization)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Delivery/Organization")

      params[:recipient].delete(:is_response_requested)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Recipient/IsResponseRequested")

      params[:recipient].delete(:newsletter_opt_in)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Recipient/NewsletterOptIn")

      params[:constituent].delete(:middle_name)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Constituent/MiddleName")

      params[:constituent].delete(:suffix)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Constituent/Suffix")

      params[:constituent].delete(:title)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Constituent/Title")

      params[:constituent].delete(:organization)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Constituent/Organization")

      params[:constituent][:address].pop
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Constituent/Address3")

      params[:constituent][:address].pop
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Constituent/Address2")

      params[:constituent].delete(:phone)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Constituent/Phone")

      params[:constituent].delete(:address_validation)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Constituent/AddressValidation")

      params[:constituent].delete(:phone)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Constituent/Phone")

      params[:constituent].delete(:email_validation)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Constituent/EmailValidation")

      params[:message][:bills].pop
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Message/Bill[2]")

      params[:message][:bills].pop
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Message/Bill")

      params[:message].delete(:pro_or_con)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Message/ProOrCon")

      params[:message].delete(:organization_statement)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Message/OrganizationStatement")

      params[:message].delete(:constituent_message)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Message/ConstituentMessage")

      params[:message].delete(:more_info)
      doc = Nokogiri::XML(create_message(params).to_xml)
      expect(create_doc(params)).not_to have_xpath("CWC/Message/MoreInfo")
    end
  end
end
