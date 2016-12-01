
require "securerandom"
require "nokogiri"

require "cwc/extensions/hash"

module Cwc
  class Message
    attr_accessor :delivery
    attr_accessor :recipient
    attr_accessor :constituent
    attr_accessor :message

    attr_accessor :delivery_id

    def initialize
      self.delivery = {}
      self.recipient = {}
      self.constituent = {}
      self.message = {}

      self.delivery_id = SecureRandom.random_number(36**33).to_s(36).rjust(12, "0")[0, 32]
    end

    def delivery_date
      Time.now.strftime("%Y%m%d")
    end

    def to_xml
      Nokogiri::XML::Builder.new do |xml|
        xml.CWC {
          xml.CWCVersion "2.0"

          delivery_section(xml)
          recipient_section(xml)
          constituent_section(xml)
          message_section(xml)
        }         
      end.to_xml
    end

    def delivery_section(xml)
      xml.Delivery {
        xml.DeliveryId delivery_id
        xml.DeliveryDate delivery_date

        xml.DeliveryAgent delivery.dig!(:agent, :name)
        xml.DeliveryAgentAckEmailAddress delivery.dig!(:agent, :ack_email)
        xml.DeliveryAgentContact {
          xml.DeliveryAgentContactName delivery.dig!(:agent, :contact_name)
          xml.DeliveryAgentContactEmail delivery.dig!(:agent, :contact_email)
          xml.DeliveryAgentContactPhone delivery.dig!(:agent, :contact_phone)
        }

        if delivery.dig(:organization, :name)
          xml.Organization delivery.dig(:organization, :name)
        end

        if (delivery.dig(:organization, :contact) || {}).keys.grep(/name|email|phone/).any?
          xml.OrganizationContact {
            if delivery.dig(:organization, :contact, :name)
              xml.OrganizationContactName delivery.dig(:organization, :contact, :name)
            end

            if delivery.dig(:organization, :contact, :email)
              xml.OrganizationContactEmail delivery.dig(:organization, :contact, :email)
            end

            if delivery.dig(:organization, :contact, :phone)
              xml.OrganizationContactPhone delivery.dig(:organization, :contact, :phone)
            end
          }
        end

        if delivery.dig(:organization, :about)
          xml.OrganizationAbout delivery.dig(:organization, :about)
        end

        xml.CampaignId delivery.fetch(:campaign_id)
      }
    end

    def recipient_section(xml)
      xml.Recipient {
        xml.MemberOffice recipient.fetch(:member_office)

        if recipient[:is_response_requested]
          xml.IsResponseRequested "Y"
        end

        if recipient[:newsletter_opt_in]
          xml.NewsletterOptIn "Y"
        end
      }
    end

    def constituent_section(xml)
      xml.Constituent {
        xml.Prefix constituent.fetch(:prefix)
        xml.FirstName constituent.fetch(:first_name)

        if constituent[:middle_name]
          xml.MiddleName constituent[:middle_name]
        end

        xml.LastName constituent.fetch(:last_name)

        if constituent[:suffix]
          xml.Suffix constituent[:suffix]
        end        

        if constituent[:title]
          xml.Title constituent[:title]
        end

        if constituent[:organization]
          xml.Organization constituent[:organization]
        end

        xml.Address1 Array(constituent.fetch(:address))[0]
        if Array(constituent[:address])[1]
          xml.Address2 Array(constituent[:address])[1]

          if Array(constituent[:address])[2]
            xml.Address3 Array(constituent[:address])[2]
          end
        end
        xml.City constituent.fetch(:city)
        xml.StateAbbreviation constituent.fetch(:state_abbreviation)
        xml.Zip constituent.fetch(:zip)

        if constituent[:phone]
          xml.Phone constituent[:phone]
        end

        if constituent[:address_validation]
          xml.AddressValidation "Y"
        end

        xml.Email constituent.fetch(:email)

        if constituent[:email_validation]
          xml.EmailValidation "Y"
        end
      }
    end

    def message_section(xml)
      xml.Message {
        xml.Subject message.fetch(:subject)

        xml.LibraryOfCongressTopics {
          message.fetch(:library_of_congress_topics).each do |topic|
            xml.LibraryOfCongressTopic topic
          end
        }

        Array(message[:bills]).each do |bill|
          xml.Bill {
            xml.BillCongress bill[:congress]
            xml.BillTypeAbbreviation bill[:type_abbreviation]
            xml.BillNumber bill[:number]
          }
        end

        if message[:pro_or_con]
          xml.ProOrCon message[:pro_or_con]
        end

        if message[:organization_statement]
          xml.OrganizationStatement message[:organization_statement]
        end

        if message[:constituent_message]
          xml.ConstituentMessage message[:constituent_message]
        end

        if message[:more_info]
          xml.MoreInfo message[:more_info]
        end
      }
    end
  end
end
